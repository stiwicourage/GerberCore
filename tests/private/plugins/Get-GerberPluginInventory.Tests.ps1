BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
    $script:pluginGuid = '6996218c-58d0-48ce-b6cc-38d06149230a'
    $script:declinedOnlyGuid = '11111111-2222-3333-4444-555555555555'
}

Describe 'Get-GerberPluginInventory' -Tag 'PluginCreate' {
    BeforeEach {
        $script:fixtureModuleRoot = $null
        $script:originalConfigPath = $env:GERBER_CONFIG_PATH
        $env:GERBER_CONFIG_PATH = Join-Path $TestDrive 'config.json'
        Save-GerberUserConfiguration -Configuration @{ schemaVersion = 1 }
        Reset-GerberPluginTestEnvironment
    }

    AfterEach {
        Reset-GerberPluginTestEnvironment
        if (-not [string]::IsNullOrWhiteSpace($script:fixtureModuleRoot)) {
            Remove-GerberPluginFixtureModuleRoot -Path $script:fixtureModuleRoot
        }
        $env:GERBER_CONFIG_PATH = $script:originalConfigPath
    }

    It 'uses cached creation metadata only for missing modules and keeps list and info read-only' -Tag 'PluginCreate' -ForEach @(
        @{ Discover = $false; ExpectedName = 'Gerber.Created'; ExpectedVersion = '0.1.0'; ExpectedState = 'Missing' }
        @{ Discover = $true; ExpectedName = 'Gerber.TestPlugin'; ExpectedVersion = '1.0.0'; ExpectedState = 'Enabled' }
    ) {
        $configuration = @{
            schemaVersion = 1
            plugins = @{
                approved = @($script:pluginGuid)
                associated = @{ $script:pluginGuid = @{ enabled = $true; name = 'Gerber.Created'; version = '0.1.0' } }
            }
        }
        Save-GerberUserConfiguration -Configuration $configuration
        if ($Discover) {
            $script:fixtureModuleRoot = New-GerberPluginFixtureModuleRoot -StartPath $PSScriptRoot -ModuleNameList @('Gerber.TestPlugin')
        }
        $before = Get-Content $env:GERBER_CONFIG_PATH -Raw
        Mock Import-Module { throw 'Management must not import.' }
        Mock Resolve-GerberPluginApproval { throw 'Management must not approve.' }
        Mock Save-GerberUserConfiguration { throw 'Management must not save.' }
        $paths = if ($Discover) { @($script:fixtureModuleRoot) } else { @() }
        $entry = @(Get-GerberPluginInventory -PluginModulePathList $paths)[0]
        $entry.Name | Should -Be $ExpectedName
        $entry.Version | Should -Be $ExpectedVersion
        $entry.Guid | Should -Be $script:pluginGuid
        $entry.State | Should -Be $ExpectedState
        $entry.IsEnabled | Should -BeTrue
        $entry.Loaded | Should -BeFalse
        (Get-GerberPluginListText -PluginInventory @($entry)) | Should -Match $ExpectedName
        (Get-GerberPluginInfoText -Plugin $entry) | Should -Match $ExpectedVersion
        (Get-GerberSelectedPluginInventoryEntry -PluginInventory @($entry) -LookupText $ExpectedName).Guid | Should -Be $script:pluginGuid
        (Get-Content $env:GERBER_CONFIG_PATH -Raw) | Should -Be $before
        Should -Invoke Import-Module -Times 0
        Should -Invoke Save-GerberUserConfiguration -Times 0
        Should -Invoke Resolve-GerberPluginApproval -Times 0
    }

    It 'returns no rows when no plugins are discovered or persisted' {
        $result = @(Get-GerberPluginInventory -PluginModulePathList @())

        $result | Should -Be @()
    }

    It 'reports an approved enabled plugin as loaded and shows its registered commands' {
        $script:fixtureModuleRoot = New-GerberPluginFixtureModuleRoot `
            -StartPath $PSScriptRoot `
            -ModuleNameList @('Gerber.TestPlugin')
        Save-GerberUserConfiguration -Configuration @{
            schemaVersion = 1
            plugins = @{
                approved = @($script:pluginGuid)
                associated = @{
                    '6996218c-58d0-48ce-b6cc-38d06149230a' = @{
                        enabled = $true
                    }
                }
            }
        }
        Clear-GerberCommandRegistry
        $null = Initialize-GerberCommandRegistry -PluginModulePathList @($script:fixtureModuleRoot)

        $result = @(Get-GerberPluginInventory -PluginModulePathList @($script:fixtureModuleRoot))

        $result.Count | Should -Be 1
        $result[0].ApprovalStatus | Should -Be 'Approved'
        $result[0].State | Should -Be 'Enabled'
        $result[0].Loaded | Should -BeTrue
        $result[0].RegisteredNamespaceList | Should -Be @('example')
        $result[0].RegisteredCommandList | Should -Be @('example')
    }

    It 'reports merged plugin lifecycle states without loading them unexpectedly' -ForEach @(
        @{
            Title = 'unknown discovered plugin'
            DiscoverPlugin = $true
            Configuration = @{ schemaVersion = 1 }
            Expected = @{
                Name = 'Gerber.TestPlugin'
                ApprovalStatus = 'Unknown'
                State = 'Discovered'
                IsAssociated = $false
                Loaded = $false
            }
        }
        @{
            Title = 'approved disabled plugin'
            DiscoverPlugin = $true
            InitializeRegistry = $true
            Configuration = @{
                schemaVersion = 1
                plugins = @{
                    approved = @('6996218c-58d0-48ce-b6cc-38d06149230a')
                    associated = @{
                        '6996218c-58d0-48ce-b6cc-38d06149230a' = @{
                            enabled = $false
                        }
                    }
                }
            }
            Expected = @{
                ApprovalStatus = 'Approved'
                State = 'Disabled'
                Loaded = $false
            }
        }
        @{
            Title = 'declined discovered plugin'
            DiscoverPlugin = $true
            Configuration = @{
                schemaVersion = 1
                plugins = @{
                    declined = @('6996218c-58d0-48ce-b6cc-38d06149230a')
                }
            }
            Expected = @{
                ApprovalStatus = 'Declined'
                State = 'Discovered'
                Loaded = $false
            }
        }
        @{
            Title = 'declined persisted-only plugin'
            Configuration = @{
                schemaVersion = 1
                plugins = @{
                    declined = @('11111111-2222-3333-4444-555555555555')
                }
            }
            Expected = @{
                DisplayName = '11111111-2222-3333-4444-555555555555'
                ApprovalStatus = 'Declined'
                State = 'Not discovered'
                Version = $null
            }
        }
        @{
            Title = 'associated missing plugin'
            Configuration = @{
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
            Expected = @{
                ApprovalStatus = 'Approved'
                IsAssociated = $true
                State = 'Missing'
                Name = $null
            }
        }
        @{
            Title = 'approved discovered unassociated plugin'
            DiscoverPlugin = $true
            Configuration = @{
                schemaVersion = 1
                plugins = @{
                    approved = @('6996218c-58d0-48ce-b6cc-38d06149230a')
                }
            }
            Expected = @{
                ApprovalStatus = 'Approved'
                IsAssociated = $false
                State = 'Discovered'
            }
        }
    ) {
        param($Configuration, $DiscoverPlugin, $InitializeRegistry, $Expected)

        if ($DiscoverPlugin) {
            $script:fixtureModuleRoot = New-GerberPluginFixtureModuleRoot `
                -StartPath $PSScriptRoot `
                -ModuleNameList @('Gerber.TestPlugin')
        }
        Save-GerberUserConfiguration -Configuration $Configuration
        if ($InitializeRegistry) {
            Clear-GerberCommandRegistry
            $null = Initialize-GerberCommandRegistry -PluginModulePathList @($script:fixtureModuleRoot)
        }

        $pluginModulePathList = if ($DiscoverPlugin) {
            @($script:fixtureModuleRoot)
        } else {
            @()
        }
        $result = @(Get-GerberPluginInventory -PluginModulePathList $pluginModulePathList)

        $result.Count | Should -Be 1
        foreach ($propertyName in $Expected.Keys) {
            $result[0].$propertyName | Should -Be $Expected[$propertyName]
        }
    }

    It 'merges persisted and discovered information for the same GUID into one row' {
        $script:fixtureModuleRoot = New-GerberPluginFixtureModuleRoot `
            -StartPath $PSScriptRoot `
            -ModuleNameList @('Gerber.TestPlugin')
        Save-GerberUserConfiguration -Configuration @{
            schemaVersion = 1
            plugins = @{
                declined = @($script:pluginGuid)
            }
        }

        $result = @(Get-GerberPluginInventory -PluginModulePathList @($script:fixtureModuleRoot))

        $result.Count | Should -Be 1
        $result[0].Name | Should -Be 'Gerber.TestPlugin'
        $result[0].Guid | Should -Be $script:pluginGuid
    }

    It 'does not import plugin code during inventory inspection' -ForEach @(
        @{ Title = 'unknown plugin'; Configuration = @{ schemaVersion = 1 } }
        @{
            Title = 'declined plugin'
            Configuration = @{
                schemaVersion = 1
                plugins = @{
                    declined = @('6996218c-58d0-48ce-b6cc-38d06149230a')
                }
            }
        }
        @{
            Title = 'disabled plugin'
            Configuration = @{
                schemaVersion = 1
                plugins = @{
                    approved = @('6996218c-58d0-48ce-b6cc-38d06149230a')
                    associated = @{
                        '6996218c-58d0-48ce-b6cc-38d06149230a' = @{
                            enabled = $false
                        }
                    }
                }
            }
        }
    ) {
        param($Configuration)

        $script:fixtureModuleRoot = New-GerberPluginFixtureModuleRoot `
            -StartPath $PSScriptRoot `
            -ModuleNameList @('Gerber.TestPlugin')
        Save-GerberUserConfiguration -Configuration $Configuration
        Mock Import-Module {}

        $null = Get-GerberPluginInventory -PluginModulePathList @($script:fixtureModuleRoot)

        Should -Invoke Import-Module -Times 0
    }
}
