[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repositoryRoot

Import-Module NovaModuleTools -ErrorAction Stop

& (Join-Path $repositoryRoot 'scripts/build/Invoke-ScriptAnalyzerCI.ps1')
Invoke-NovaBuild
Invoke-NovaTest
Test-NovaBuild
& (Join-Path $repositoryRoot 'scripts/build/Invoke-TerminalRegressionCI.ps1')
