[CmdletBinding()]
param([string]$CoreManifest, [string]$ModuleRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$env:PSModulePath = $ModuleRoot + [System.IO.Path]::PathSeparator + $env:PSModulePath
Import-Module $CoreManifest -Force
& (Get-Module Gerber) {
    param($Root)
    Clear-GerberCommandRegistry
    $null = Initialize-GerberCommandRegistry -PluginModulePathList @($Root)
    $inventory = @(Get-GerberPluginInventory -PluginModulePathList @($Root))
    Get-GerberPluginListText -PluginInventory $inventory
    $command = Resolve-GerberCommand -InputText '/mycompany hello'
    $definition = Get-GerberRegisteredCommand -Name $command.Name
    Invoke-GerberRegisteredCommand -CommandDefinition $definition -Command $command
} $ModuleRoot
