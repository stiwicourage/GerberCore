# Real fixture modules and persisted configuration prove the enable command boundary:
# no reimport, preserved runtime context, collision rejection and approval compensation.
BeforeAll {
    $supportPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers'
    . (Join-Path $supportPath 'GerberTestSupport.ps1')
    . (Join-Path $supportPath 'Initialize-GerberPluginActivationFixture.ps1')
    . (Join-Path $supportPath 'Clear-GerberPluginActivationFixture.ps1')
    . (Join-Path $supportPath 'Get-GerberRegistryTransactionSnapshot.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Enable-GerberPlugin' -Tag 'PluginTransactions' {
    BeforeEach {
        $script:activationFixture = Initialize-GerberPluginActivationFixture -StartPath $PSScriptRoot -TestDrivePath $TestDrive
        Mock Get-GerberDefaultPluginModulePathList { [string[]]@($script:activationFixture.ModuleRoot) }
    }

    AfterEach {
        Clear-GerberPluginActivationFixture -Fixture $script:activationFixture
    }

    Context 'Activation and approval' {
        It 'approves and enables a previously declined plugin and registers its commands immediately' {
            Save-GerberUserConfiguration -Configuration @{
                schemaVersion = 1
                plugins       = @{ declined = @($script:testPluginGuid) }
            }

            $null = Enable-GerberPlugin -Guid $script:testPluginGuid

            $configuration = Get-GerberUserConfiguration
            @($configuration.plugins.approved) | Should -Contain $script:testPluginGuid
            @($configuration.plugins.declined) | Should -Not -Contain $script:testPluginGuid
            $configuration.plugins.associated.$($script:testPluginGuid).enabled | Should -BeTrue
            (Get-GerberRegisteredCommand -Name 'example').OwnerName | Should -Be 'Gerber.TestPlugin'
            Get-GerberActionList | Should -Contain 'example'
        }

        It 'enables a plugin that was approved and then disabled without another prompt' {
            Save-GerberUserConfiguration -Configuration @{
                schemaVersion = 1
                plugins       = @{
                    approved   = @($script:testPluginGuid)
                    associated = @{ $script:testPluginGuid = @{ enabled = $false } }
                }
            }
            Mock Read-GerberConfirmationPrompt { throw 'No approval prompt is expected.' }

            $null = Enable-GerberPlugin -Guid $script:testPluginGuid

            (Get-GerberPluginLifecycleState -Guid $script:testPluginGuid).IsEnabled | Should -BeTrue
            Get-GerberRegisteredCommand -Name 'example' | Should -Not -BeNullOrEmpty
        }

        It 'enables a pending plugin that has no stored decision' {
            $null = Enable-GerberPlugin -Guid $script:testPluginGuid

            $configuration = Get-GerberUserConfiguration
            @($configuration.plugins.approved) | Should -Contain $script:testPluginGuid
            (Get-GerberPluginLifecycleState -Guid $script:testPluginGuid).ShouldLoad | Should -BeTrue
        }

        It 'keeps one registration when the plugin is enabled twice in a row' {
            $null = Enable-GerberPlugin -Guid $script:testPluginGuid
            $command = Get-GerberRegisteredCommand -Name 'example'
            $null = Invoke-GerberRegisteredCommand -CommandDefinition $command -Command ([pscustomobject]@{ Name = 'example' })
            $context = Get-GerberTestPluginRegistrationContext
            $before = Get-GerberRegistryTransactionSnapshot
            Mock Import-Module { throw 'must not reimport' }
            Mock New-GerberPluginApiContext { throw 'must not initialize' }
            Mock Resolve-GerberPluginApproval { throw 'must not approve again' }
            Mock Save-GerberUserConfiguration { throw 'must not persist again' }

            $null = Enable-GerberPlugin -Guid $script:testPluginGuid

            Get-GerberTestPluginInvocationCount | Should -Be 1
            [object]::ReferenceEquals((Get-GerberTestPluginRegistrationContext), $context) | Should -BeTrue
            Get-GerberRegistryTransactionSnapshot | Should -Be $before
            Should -Invoke Import-Module -Times 0 -Exactly
            Should -Invoke New-GerberPluginApiContext -Times 0 -Exactly
            Should -Invoke Resolve-GerberPluginApproval -Times 0 -Exactly
            Should -Invoke Save-GerberUserConfiguration -Times 0 -Exactly
            @(Get-GerberCommandRegistry | Where-Object Name -EQ 'example').Count | Should -Be 1
            (Get-GerberPluginInventory | Where-Object Guid -EQ $script:testPluginGuid).State | Should -Be 'Enabled'
        }

        It 'leaves state and registry untouched when the plugin cannot be loaded' {
            $failureError = $null
            try {
                Enable-GerberPlugin -Guid $script:failingPluginGuid
            } catch {
                $failureError = $_.Exception.Message
            }

            $failureError | Should -Match 'could not import plugin'
            $configuration = Get-GerberUserConfiguration
            @($configuration.plugins.approved) | Should -Not -Contain $script:failingPluginGuid
            @(Get-GerberCommandRegistry | Where-Object OwnerType -EQ 'Plugin').Count | Should -Be 0
        }

        It 'rejects a distinct GUID with the active module name before import, initialization or persistence' {
            $null = Enable-GerberPlugin -Guid $script:testPluginGuid
            $original = Get-GerberInstalledPluginModuleByGuid -Guid $script:testPluginGuid
            $collision = $original.PSObject.Copy()
            $collision.Guid = $script:secondPluginGuid
            $collision.Name = $original.Name.ToLowerInvariant()
            $before = Get-GerberRegistryTransactionSnapshot
            $configuration = Get-Content -LiteralPath $env:GERBER_CONFIG_PATH -Raw
            Mock Get-GerberInstalledPluginModuleByGuid { $collision }
            Mock Import-Module { throw 'must not import collision' }
            Mock New-GerberPluginApiContext { throw 'must not initialize collision' }
            Mock Save-GerberUserConfiguration { throw 'must not persist collision' }

            { Enable-GerberPlugin -Guid $script:secondPluginGuid } | Should -Throw '*module name*'

            Get-GerberRegistryTransactionSnapshot | Should -Be $before
            Get-Content -LiteralPath $env:GERBER_CONFIG_PATH -Raw | Should -Be $configuration
            $command = Get-GerberRegisteredCommand -Name 'example'
            $null = Invoke-GerberRegisteredCommand -CommandDefinition $command -Command ([pscustomobject]@{ Name = 'example' })
            Get-GerberTestPluginInvocationCount | Should -Be 1
            Should -Invoke Import-Module -Times 0 -Exactly
            Should -Invoke New-GerberPluginApiContext -Times 0 -Exactly
            Should -Invoke Save-GerberUserConfiguration -Times 0 -Exactly
        }

        It 'rolls back registered commands when the state cannot be persisted' {
            Mock Save-GerberUserConfiguration { throw 'disk full' }

            { Enable-GerberPlugin -Guid $script:testPluginGuid } | Should -Throw '*disk full*'

            Get-GerberRegisteredCommand -Name 'example' | Should -BeNullOrEmpty
            @((Get-GerberPluginInventory | Where-Object Guid -EQ $script:testPluginGuid).Loaded) | Should -Not -Contain $true
        }

        It 'reports a plugin that is no longer installed' {
            Remove-Item -LiteralPath (Join-Path $script:activationFixture.ModuleRoot 'Gerber.TestPlugin') -Recurse -Force

            { Enable-GerberPlugin -Guid $script:testPluginGuid } | Should -Throw '*no longer installed*'
        }
    }

}
