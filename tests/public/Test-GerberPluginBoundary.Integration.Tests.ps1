Describe 'Installed Gerber plugin boundary command' -Tag 'PluginBoundary' {
    It 'works without Core checkout access, an active Gerber session or importing plugin source' {
        $installed = Join-Path $TestDrive 'modules/Gerber'
        $null = New-Item -ItemType Directory (Split-Path $installed) -Force
        Copy-Item (Join-Path $PSScriptRoot '../../dist/Gerber') $installed -Recurse -Force
        $projectPath = Join-Path $TestDrive 'Gerber.Uninstalled'
        $null = New-Item -ItemType Directory "$projectPath/src/private" -Force
        Set-Content "$projectPath/src/private/Invalid.ps1" "throw 'do not execute'; Get-GerberCommandRegistry"
        $probe = Join-Path $TestDrive 'probe.ps1'
        Set-Content $probe @'
param($Manifest, $ProjectPath)
$ErrorActionPreference = 'Stop'
Import-Module $Manifest -Force
$result = Test-GerberPluginBoundary -Path $ProjectPath
if ($result.IsValid -or $result.Diagnostics[0].Dependency -ne 'Get-GerberCommandRegistry') { throw 'Missing boundary diagnostic' }
if ($result.PublicApi.UI -notcontains 'ShowTextBlock') { throw 'Missing public API inventory' }
'@
        & (Join-Path $PSHOME 'pwsh') -NoLogo -NoProfile -NonInteractive -File $probe `
            -Manifest (Join-Path $installed 'Gerber.psd1') -ProjectPath $projectPath
        $LASTEXITCODE | Should -Be 0
    }
}
