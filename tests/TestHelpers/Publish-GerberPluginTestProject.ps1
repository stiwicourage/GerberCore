[CmdletBinding(SupportsShouldProcess)]
param([string]$ProjectPath, [string]$ModuleRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $ProjectPath
Import-Module NovaModuleTools -ErrorAction Stop
if ($PSCmdlet.ShouldProcess($ModuleRoot, 'Publish isolated generated test plugin locally')) {
    Publish-NovaModule -Local -ModuleDirectoryPath $ModuleRoot
}
