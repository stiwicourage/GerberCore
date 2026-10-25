[CmdletBinding()]
param(
    [string]$ScenarioId,

    [string]$Category,

    [switch]$KeepSuccessArtifacts,

    [ValidateRange(10, 1800)]
    [int]$DependencyInstallTimeoutSeconds = 180,

    [ValidateRange(30, 7200)]
    [int]$SuiteTimeoutSeconds = 900
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$artifactRoot = Join-Path $repositoryRoot 'artifacts/terminal'
$requirementsPath = Join-Path $repositoryRoot 'tests/terminal/requirements.txt'
$venvRoot = Join-Path $artifactRoot '.venv'
$venvPython = Join-Path $venvRoot 'bin/python'
$stampPath = Join-Path $venvRoot 'requirements.sha256'

function Install-GerberTerminalRequirement {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$TimeoutSeconds
    )

    $argumentList = @('-m', 'pip', 'install', '--disable-pip-version-check', '-r', $requirementsPath)
    $process = Start-Process -FilePath $venvPython -ArgumentList $argumentList -NoNewWindow -PassThru
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $process.Kill($true)
        throw "Gerber terminal dependency installation exceeded $TimeoutSeconds seconds."
    }
    if ($process.ExitCode -ne 0) {
        throw "Gerber terminal dependency installation failed with exit code $($process.ExitCode)."
    }
}

function Initialize-GerberTerminalVirtualEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$DependencyTimeoutSeconds
    )

    $requirementHash = (Get-FileHash -LiteralPath $requirementsPath -Algorithm SHA256).Hash
    $venvReady = (Test-Path -LiteralPath $venvPython -PathType Leaf) -and
        (Test-Path -LiteralPath $stampPath -PathType Leaf) -and
        ((Get-Content -LiteralPath $stampPath -Raw) -eq $requirementHash)
    if ($venvReady) {
        return
    }

    if (Test-Path -LiteralPath $venvRoot -PathType Container) {
        Remove-Item -LiteralPath $venvRoot -Recurse -Force
    }

    $null = New-Item -ItemType Directory -Path $artifactRoot -Force
    & python3 -m venv $venvRoot
    Install-GerberTerminalRequirement -TimeoutSeconds $DependencyTimeoutSeconds
    [System.IO.File]::WriteAllText($stampPath, $requirementHash, [System.Text.Encoding]::UTF8)
}

Initialize-GerberTerminalVirtualEnvironment -DependencyTimeoutSeconds $DependencyInstallTimeoutSeconds

$selfTestArgumentList = @(
    '-m'
    'unittest'
    'discover'
    '-s'
    (Join-Path $repositoryRoot 'tests/terminal/selftests')
    '-p'
    'test_*.py'
)
& $venvPython @selfTestArgumentList
if ($LASTEXITCODE -ne 0) {
    throw "Gerber terminal self-tests failed with exit code $LASTEXITCODE."
}

$runnerPath = Join-Path $repositoryRoot 'tests/terminal/run_terminal_tests.py'
$argumentList = @(
    $runnerPath
    '--gerber-root'
    $repositoryRoot
    '--artifact-root'
    $artifactRoot
    '--suite-timeout-seconds'
    $SuiteTimeoutSeconds
)
if (-not [string]::IsNullOrWhiteSpace($ScenarioId)) {
    $argumentList += @('--scenario-id', $ScenarioId)
}

if (-not [string]::IsNullOrWhiteSpace($Category)) {
    $argumentList += @('--category', $Category)
}

if ($KeepSuccessArtifacts) {
    $argumentList += '--keep-success-artifacts'
}

& $venvPython @argumentList
if ($LASTEXITCODE -ne 0) {
    throw "Gerber terminal regression tests failed with exit code $LASTEXITCODE."
}
