[CmdletBinding()]
param([Parameter(Mandatory)][string]$ProjectPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try {
    Set-Location -LiteralPath $ProjectPath
    Import-Module NovaModuleTools -ErrorAction Stop
    Invoke-NovaBuild
    Invoke-NovaTest -OutputVerbosity Normal
    Test-NovaBuild -OutputVerbosity Normal
} catch {
    Write-Error -Message $_.Exception.Message -ErrorAction Continue
    exit 1
}
