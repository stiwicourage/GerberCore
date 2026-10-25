<#
.SYNOPSIS
Creates a fake ScriptAnalyzer result for wrapper tests.
#>
function Get-FakeScriptAnalyzerResult {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [hashtable]$PropertyOverrides = @{}
    )

    $propertyMap = @{
        Severity     = 'Warning'
        RuleName     = 'Rule.Default'
        RelativePath = 'src/test.ps1'
        Line         = 3
        Message      = 'Test finding.'
    }

    foreach ($propertyName in $PropertyOverrides.Keys) {
        $propertyMap[$propertyName] = $PropertyOverrides[$propertyName]
    }

    return [pscustomobject]@{
        Severity   = $propertyMap.Severity
        RuleName   = $propertyMap.RuleName
        ScriptPath = Join-Path $env:GERBER_SCRIPTANALYZER_TEST_PROJECT_ROOT $propertyMap.RelativePath
        Line       = $propertyMap.Line
        Message    = $propertyMap.Message
    }
}

<#
.SYNOPSIS
Builds a temporary repository and fake PSScriptAnalyzer module for wrapper tests.
#>
function Get-ScriptAnalyzerHarness {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [object[]]$Findings = @(),
        [switch]$ThrowOnAnalyze
    )

    $moduleRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $repoRoot = Join-Path $moduleRoot 'repo'
    $pssaRoot = Join-Path $moduleRoot 'PSScriptAnalyzer/1.25.0'
    $null = New-Item -ItemType Directory -Path (Join-Path $repoRoot 'scripts/build') -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $repoRoot 'src') -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $repoRoot 'tests') -Force
    $null = New-Item -ItemType Directory -Path $pssaRoot -Force
    Copy-Item -LiteralPath $env:GERBER_SCRIPTANALYZER_TEST_SCRIPT_PATH -Destination (Join-Path $repoRoot 'scripts/build/Invoke-ScriptAnalyzerCI.ps1')
    Set-Content -LiteralPath (Join-Path $repoRoot 'src/Sample.ps1') -Value "function Get-Sample { 'ok' }"
    Set-Content -LiteralPath (Join-Path $repoRoot 'tests/Sample.Tests.ps1') -Value "Describe 'Sample' { It 'works' { \$true | Should -BeTrue } }"

    $serializedFindings = $Findings | ConvertTo-Json -Depth 6 -Compress
    $throwLine = if ($ThrowOnAnalyze) {
        "throw 'Fake analyzer failure.'"
    } else {
        '$resultList = @()'
    }
    $resultLine = if ($ThrowOnAnalyze) {
        ''
    } else {
        @"
            foreach (`$item in @(`$decoded.Findings)) {
                `$resultList += [pscustomobject]@{
                    Severity = `$item.Severity
                    RuleName = `$item.RuleName
                    ScriptPath = [System.IO.Path]::GetFullPath((Join-Path `$env:GERBER_FAKE_REPOSITORY_ROOT `$item.RelativePath))
                    Line = [int]`$item.Line
                    Message = `$item.Message
                }
            }
            return `$resultList
"@
    }

    @"
`$script:moduleVersion = '1.25.0'
function Invoke-ScriptAnalyzer {
    param([string]`$Path)

    `$decoded = '$serializedFindings' | ConvertFrom-Json
    $throwLine
    $resultLine
}
"@ | Set-Content -LiteralPath (Join-Path $pssaRoot 'PSScriptAnalyzer.psm1')

    @"
@{
    RootModule = 'PSScriptAnalyzer.psm1'
    ModuleVersion = '1.25.0'
    GUID = '11111111-1111-1111-1111-111111111111'
}
"@ | Set-Content -LiteralPath (Join-Path $pssaRoot 'PSScriptAnalyzer.psd1')

    return [pscustomobject]@{
        ModuleRoot = $moduleRoot
        RepositoryRoot = $repoRoot
        ScriptPath = Join-Path $repoRoot 'scripts/build/Invoke-ScriptAnalyzerCI.ps1'
    }
}

<#
.SYNOPSIS
Runs pwsh as a child process and captures its exit code and output.
#>
function Invoke-PwshProcess {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [string[]]$ArgumentList
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = 'pwsh'
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    foreach ($argument in $ArgumentList) {
        $null = $startInfo.ArgumentList.Add($argument)
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $null = $process.Start()

    $standardOutput = $process.StandardOutput.ReadToEnd()
    $standardError = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    return [pscustomobject]@{
        ExitCode       = $process.ExitCode
        StandardOutput = $standardOutput
        StandardError  = $standardError
    }
}

Export-ModuleMember -Function Get-FakeScriptAnalyzerResult, Get-ScriptAnalyzerHarness, Invoke-PwshProcess
