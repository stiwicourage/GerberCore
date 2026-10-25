Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:NativeCredentialRepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path

function Get-NativeCredentialRuntime {
    $platform = 'Linux'
    if ($IsWindows) { $platform = 'Windows' }
    if ($IsMacOS) { $platform = 'macOS' }
    return [pscustomobject]@{
        Version = $PSVersionTable.PSVersion
        OS = $platform
        Architecture = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
    }
}

function Assert-NativeCredentialRunner {
    $runtime = Get-NativeCredentialRuntime
    if ($runtime.Version -lt [version]'7.4') { throw 'PowerShell >= 7.4 is required.' }
    $expected = @{
        GITHUB_ACTIONS = 'true'
        RUNNER_ENVIRONMENT = 'github-hosted'
        RUNNER_OS = $runtime.OS
        RUNNER_ARCH = $runtime.Architecture
    }
    foreach ($name in $expected.Keys) {
        if ([Environment]::GetEnvironmentVariable($name) -ine $expected[$name]) {
            throw "Native credentials require a matching disposable GitHub-hosted runner ($name)."
        }
    }
}

function Get-NativeCredentialReportCount {
    param([System.Xml.XmlElement]$Element, [string]$Name)
    $value = $Element.GetAttribute($Name)
    $count = 0
    if ($value -notmatch '^[0-9]+$' -or -not [int]::TryParse($value, [ref]$count)) {
        throw "Invalid native credential report count: $Name."
    }
    return $count
}

function Assert-NativeCredentialSuiteCounter {
    param([System.Xml.XmlElement]$Suite, [hashtable]$Counts)
    $attributes = @{ total = 'total'; failed = 'failures'; inconclusive = 'inconclusive'; skipped = 'skipped' }
    foreach ($name in $attributes.Keys) {
        if ((Get-NativeCredentialReportCount -Element $Suite -Name $name) -ne $Counts[$attributes[$name]]) {
            throw "Inconsistent native credential report count: $name."
        }
    }
}

function Get-NativeCredentialReportCounter {
    param([xml]$Report)
    $success = '/test-results/test-suite[@executed="True" and @result="Success" and @success="True"]'
    if ($Report.SelectNodes($success).Count -ne 1 -or $Report.SelectNodes('/test-results/test-suite').Count -ne 1) {
        throw 'Expected one successful, executed Nova NUnit summary.'
    }
    $counts = @{}
    foreach ($name in @('total', 'errors', 'failures', 'inconclusive', 'skipped')) {
        $counts[$name] = Get-NativeCredentialReportCount -Element $Report.DocumentElement -Name $name
    }
    $suite = $Report.SelectSingleNode('/test-results/test-suite')
    $counts.passed = Get-NativeCredentialReportCount -Element $suite -Name 'passed'
    Assert-NativeCredentialSuiteCounter -Suite $suite -Counts $counts
    return $counts
}

function Assert-NativeCredentialReport {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][datetime]$NotBefore)
    if ((Get-Item -LiteralPath $Path -ErrorAction Stop).LastWriteTimeUtc -lt $NotBefore) {
        throw 'A fresh native credential report is required.'
    }
    [xml]$report = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    $counts = Get-NativeCredentialReportCounter -Report $report
    # Nova's raw total includes NotRun cases. Validate the executed denominator.
    $executed = $counts.passed + $counts.failures + $counts.errors + $counts.inconclusive + $counts.skipped
    if ($counts.total -lt $executed) {
        throw 'Native credential report total is smaller than its executed count.'
    }
    if ($executed -ne 2 -or $counts.passed -ne 2) {
        throw 'Expected exactly two executed native credential tests: 2 passed, 0 failed/errors/inconclusive/skipped.'
    }
}

function Invoke-NativeCredentialSelection {
    $optIn = $env:GERBER_RUN_NATIVE_CREDENTIAL_TESTS
    $store = $env:GCM_CREDENTIAL_STORE
    try {
        $env:GERBER_RUN_NATIVE_CREDENTIAL_TESTS = '1'
        $env:GCM_CREDENTIAL_STORE = $null
        Test-NovaBuild -TagFilter NativeCredentialStore -OutputVerbosity Detailed -OutputRenderMode Ansi
    } finally {
        $env:GERBER_RUN_NATIVE_CREDENTIAL_TESTS = $optIn
        $env:GCM_CREDENTIAL_STORE = $store
    }
}

function Invoke-NativeCredentialTest {
    param([Parameter(Mandatory)][string]$ReportPath)
    if (Test-Path -LiteralPath $ReportPath) {
        Remove-Item -LiteralPath $ReportPath -Force -ErrorAction Stop
    }
    $startedAt = [datetime]::UtcNow
    Invoke-NativeCredentialSelection
    Assert-NativeCredentialReport -Path $ReportPath -NotBefore $startedAt
}

function Invoke-NativeCredentialPlatformCI {
    Assert-NativeCredentialRunner
    Write-Host "Native backend: $env:RUNNER_OS/$env:RUNNER_ARCH; PowerShell $($PSVersionTable.PSVersion); image $env:ImageOS $env:ImageVersion"
    Push-Location -LiteralPath $script:NativeCredentialRepositoryRoot
    try {
        Import-Module NovaModuleTools -MinimumVersion 3.4.2 -ErrorAction Stop
        Import-Module PSModuleUpdate -MinimumVersion 0.1.0 -ErrorAction Stop
        Invoke-NovaBuild
        Invoke-NativeCredentialTest -ReportPath (Join-Path $script:NativeCredentialRepositoryRoot 'artifacts/TestResults.xml')
    } finally {
        Pop-Location
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-NativeCredentialPlatformCI
}
