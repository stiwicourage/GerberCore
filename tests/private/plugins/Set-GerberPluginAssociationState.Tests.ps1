BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot

    function Use-GerberPluginAssociationConfigurationPathMock {
        param(
            [Parameter(Mandatory)]
            [string]$ConfigPath
        )

        $script:GerberPluginAssociationConfigPath = $ConfigPath
        Mock Resolve-GerberUserConfigPath { $script:GerberPluginAssociationConfigPath }
    }
}

Describe 'Set-GerberPluginAssociationState' -Tag 'PluginCreate' {
    It 'preserves cached metadata through disable and enable without changing identity' -Tag 'PluginCreate' {
        Use-GerberPluginAssociationConfigurationPathMock -ConfigPath (Join-Path $TestDrive 'metadata.json')
        $guid = '6996218c-58d0-48ce-b6cc-38d06149230a'
        $configuration = @{ schemaVersion = 1 }
        Set-GerberPluginAssociationState -Configuration $configuration -Guid $guid -Enabled $true `
            -DisplayMetadata @{ name = 'Gerber.Created'; version = '0.1.0' } | Should -BeTrue
        foreach ($enabled in @($false, $true)) {
            Set-GerberPluginAssociationState -Configuration $configuration -Guid $guid -Enabled $enabled | Should -BeTrue
            $record = (Get-GerberUserConfiguration).plugins.associated[$guid]
            $record.enabled | Should -Be $enabled
            $record.name | Should -Be 'Gerber.Created'
            $record.version | Should -Be '0.1.0'
        }
    }

    It 'persists an associated enabled plugin while preserving unrelated configuration' {
        $configPath = Join-Path $TestDrive 'user/config.json'
        $configuration = @{
            schemaVersion = 1
            preferences = @{
                theme = 'dark'
            }
        }
        Use-GerberPluginAssociationConfigurationPathMock -ConfigPath $configPath

        $changed = Set-GerberPluginAssociationState `
            -Configuration $configuration `
            -Guid '6996218c-58d0-48ce-b6cc-38d06149230a' `
            -Enabled $true

        $changed | Should -BeTrue
        $reloadedConfiguration = Get-GerberUserConfiguration
        $reloadedConfiguration.preferences.theme | Should -Be 'dark'
        $reloadedConfiguration.plugins.associated.'6996218c-58d0-48ce-b6cc-38d06149230a'.enabled | Should -BeTrue
    }

    It 'preserves approval when disabling an associated plugin' {
        $configPath = Join-Path $TestDrive 'user/config.json'
        $configuration = @{
            schemaVersion = 1
            plugins = @{
                approved = @('6996218c-58d0-48ce-b6cc-38d06149230a')
                associated = @{
                    '6996218c-58d0-48ce-b6cc-38d06149230a' = @{
                        enabled = $true
                    }
                }
            }
        }
        Use-GerberPluginAssociationConfigurationPathMock -ConfigPath $configPath

        $changed = Set-GerberPluginAssociationState `
            -Configuration $configuration `
            -Guid '6996218c-58d0-48ce-b6cc-38d06149230a' `
            -Enabled $false

        $changed | Should -BeTrue
        $reloadedConfiguration = Get-GerberUserConfiguration
        @($reloadedConfiguration.plugins.approved) | Should -Be @('6996218c-58d0-48ce-b6cc-38d06149230a')
        $reloadedConfiguration.plugins.associated.'6996218c-58d0-48ce-b6cc-38d06149230a'.enabled | Should -BeFalse
    }

    It 'does not rewrite an unchanged association state' {
        $configPath = Join-Path $TestDrive 'user/config.json'
        $configuration = @{
            schemaVersion = 1
            plugins = @{
                associated = @{
                    '6996218c-58d0-48ce-b6cc-38d06149230a' = @{
                        enabled = $false
                    }
                }
            }
        }
        Use-GerberPluginAssociationConfigurationPathMock -ConfigPath $configPath
        Mock Save-GerberUserConfiguration { throw 'Save should not be called.' }

        $changed = Set-GerberPluginAssociationState `
            -Configuration $configuration `
            -Guid '6996218c-58d0-48ce-b6cc-38d06149230a' `
            -Enabled $false

        $changed | Should -BeFalse
        Should -Invoke Save-GerberUserConfiguration -Times 0
    }

    It 'rejects an invalid plugin GUID' {
        Use-GerberPluginAssociationConfigurationPathMock -ConfigPath (Join-Path $TestDrive 'user/config.json')

        {
            Set-GerberPluginAssociationState -Configuration @{ schemaVersion = 1 } -Guid 'not-a-guid' -Enabled $true
        } | Should -Throw '*invalid GUID*'
    }
}
