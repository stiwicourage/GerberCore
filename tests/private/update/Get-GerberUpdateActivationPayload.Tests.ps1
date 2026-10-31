BeforeAll {
    . (Join-Path $PSScriptRoot '../../TestHelpers/PluginUpdate.TestSupport.ps1')
    $path = Join-Path $backendRoot 'update/Get-GerberUpdateActivationPayload.ps1'
    if (Test-Path $path) {
        . $path
    }
}

Describe 'Get-GerberUpdateActivationPayload' -Tag 'G4A9' {
    BeforeEach {
        $script:item = Get-TestPluginUpdateItem
        $script:core = Get-TestCoreUpdateState
        $script:result = Get-TestPluginInstallResult
        $script:item.State.Plan | Add-Member -NotePropertyMembers @{
            ModuleGuid          = $script:item.Plugin.Guid
            TargetInstalledPath = Join-Path $TestDrive 'Gerber.Example/2.0.0'
        }
        $script:core.Plan | Add-Member -NotePropertyMembers @{
            InstalledManifestPath = Join-Path $TestDrive 'Gerber/0.2.0/Gerber.psd1'
            TargetInstalledPath   = Join-Path $TestDrive 'Gerber/0.3.0'
        }
        $script:result | Add-Member -NotePropertyMembers @{
            ModuleName    = $script:item.Plugin.Name
            ModuleGuid    = $script:item.Plugin.Guid
            Scope         = 'CurrentUser'
            InstalledPath = $script:item.State.Plan.TargetInstalledPath
        }
        Mock Get-GerberPluginInventory {
            @()
        }
    }

    It 'uses exact public PMU installation references without serializing plans or credentials' {
        $data = Get-GerberUpdateActivationPayload $script:item $script:result $script:core '0.3.0'
        $data.CoreManifest | Should -Be (Join-Path $script:core.Plan.TargetInstalledPath 'Gerber.psd1')
        $data.Target.Path | Should -Be (Join-Path $script:result.InstalledPath 'Gerber.Example.psd1')
        $data.Target.Guid | Should -Be $script:item.Plugin.Guid
        $data.Target.Version | Should -Be '2.0.0'
        ($data | ConvertTo-Json -Depth 8) | Should -Not -Match 'Credential|Disposition|RepositoryUri|TargetInstalledPath'
    }

    It 'retains the original installed Core reference when no Core update succeeded' {
        $data = Get-GerberUpdateActivationPayload $script:item $script:result $script:core '0.2.0'
        $data.CoreManifest | Should -Be $script:core.Plan.InstalledManifestPath
    }

    It 'rejects a result with a different identity, scope, target or installation path' -ForEach @(
        @{
            Field = 'ModuleGuid'
            Value = '00000000-0000-0000-0000-000000000001'
        },
        @{
            Field = 'Scope'
            Value = 'AllUsers'
        },
        @{
            Field = 'InstalledVersion'
            Value = '3.0.0'
        },
        @{
            Field = 'InstalledPath'
            Value = '/different-installation'
        }
    ) {
        $script:result.$Field = $Value
        {
            Get-GerberUpdateActivationPayload $script:item $script:result $script:core '0.3.0'
        } | Should -Throw '*does not match the selected update*'
    }
}
