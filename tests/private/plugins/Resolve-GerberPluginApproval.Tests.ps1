BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot

    function Get-GerberApprovalTestPlugin {
        return [pscustomobject]@{
            Name = 'Gerber.TestPlugin'
            Guid = '6996218c-58d0-48ce-b6cc-38d06149230a'
            Version = [version]'1.0.0'
            Author = 'Fixture Publisher'
            CompanyName = 'Fixture Company'
            Path = '/tmp/Gerber.TestPlugin/Gerber.TestPlugin.psd1'
        }
    }

}

Describe 'Resolve-GerberPluginApproval' -Tag 'PluginCreate' {
    BeforeEach {
        $script:configuration = @{ schemaVersion = 1 }
        $script:savedConfiguration = $null
        Mock Get-GerberUserConfiguration { $script:configuration }
        Mock Save-GerberUserConfiguration { $script:savedConfiguration = $Configuration }
    }

    It 'persists generated display metadata in the same approval association transaction' -Tag 'PluginCreate' {
        $result = Resolve-GerberPluginApproval -PluginModule (Get-GerberApprovalTestPlugin) -ExplicitApproval `
            -DisplayMetadata @{ name = 'Gerber.Created'; version = '0.1.0' }
        $result | Should -BeTrue
        $record = $script:savedConfiguration.plugins.associated.'6996218c-58d0-48ce-b6cc-38d06149230a'
        $record.name | Should -Be 'Gerber.Created'
        $record.version | Should -Be '0.1.0'
        $record.enabled | Should -BeTrue
        $script:savedConfiguration.plugins.approved | Should -Contain '6996218c-58d0-48ce-b6cc-38d06149230a'
        Should -Invoke Save-GerberUserConfiguration -Times 1 -Exactly
    }

    It 'uses stored plugin decisions without prompting' -ForEach @(
        @{
            Configuration = @{
                schemaVersion = 1
                plugins = @{
                    approved = @('6996218c-58d0-48ce-b6cc-38d06149230a')
                }
            }
            ConfigurationUpdate = {
                param($Configuration)

                $Configuration.plugins.associated = @{
                    '6996218c-58d0-48ce-b6cc-38d06149230a' = @{
                        enabled = $true
                    }
                }
            }
            ExpectedResult = $true
        }
        @{
            Configuration = @{
                schemaVersion = 1
                plugins = @{
                    declined = @('6996218c-58d0-48ce-b6cc-38d06149230a')
                }
            }
            ConfigurationUpdate = { }
            ExpectedResult = $false
        }
    ) {
        param($Configuration, $ConfigurationUpdate, $ExpectedResult)

        $script:configuration = $Configuration
        & $ConfigurationUpdate $script:configuration
        Mock Test-GerberInteractivePromptAvailable { throw 'Prompt availability should not be checked.' }
        Mock Read-GerberConfirmationPrompt { throw 'Approval prompt should not be shown.' }

        $result = Resolve-GerberPluginApproval -PluginModule (Get-GerberApprovalTestPlugin)

        $result | Should -Be $ExpectedResult
        Should -Invoke Save-GerberUserConfiguration -Times 0
    }

    It 'persists an accepted approval while preserving unrelated configuration' {
        $script:configuration.preferences = @{ theme = 'dark' }
        Mock Test-GerberInteractivePromptAvailable { $true }
        Mock Read-GerberConfirmationPrompt { $true }

        $result = Resolve-GerberPluginApproval -PluginModule (Get-GerberApprovalTestPlugin)

        $result | Should -BeTrue
        $script:savedConfiguration.preferences.theme | Should -Be 'dark'
        @($script:savedConfiguration.plugins.approved) |
            Should -Be @('6996218c-58d0-48ce-b6cc-38d06149230a')
        $script:savedConfiguration.plugins.associated.'6996218c-58d0-48ce-b6cc-38d06149230a'.enabled | Should -BeTrue
        Should -Invoke Read-GerberConfirmationPrompt -Times 1 -ParameterFilter {
            $Prompt -eq 'Approve this plugin?' -and
            $ScreenTitle -eq 'Unknown Gerber plugin detected' -and
            $ScreenText -match 'Gerber.TestPlugin' -and
            $ScreenText -match '6996218c-58d0-48ce-b6cc-38d06149230a' -and
            $PromptOptionSet.DefaultOption -eq 'cancel'
        }
    }

    It 'persists a declined plugin decision while preserving unrelated configuration' {
        $script:configuration.preferences = @{ theme = 'dark' }
        Mock Test-GerberInteractivePromptAvailable { $true }
        Mock Read-GerberConfirmationPrompt { $false }

        $result = Resolve-GerberPluginApproval -PluginModule (Get-GerberApprovalTestPlugin)

        $result | Should -BeFalse
        $script:savedConfiguration.preferences.theme | Should -Be 'dark'
        @($script:savedConfiguration.plugins.declined) |
            Should -Be @('6996218c-58d0-48ce-b6cc-38d06149230a')
    }

    It 'skips an unknown plugin without prompting in noninteractive execution' {
        Mock Test-GerberInteractivePromptAvailable { $false }
        Mock Read-GerberConfirmationPrompt { throw 'Approval prompt should not be shown.' }

        $warningList = @()
        $result = Resolve-GerberPluginApproval `
            -PluginModule (Get-GerberApprovalTestPlugin) `
            -WarningVariable warningList

        $result | Should -BeFalse
        @($warningList) -join ' ' | Should -Match 'Skipping unknown Gerber plugin'
        Should -Invoke Save-GerberUserConfiguration -Times 0
    }

    It 'associates a legacy approved plugin without prompting again' {
        $script:configuration.plugins = @{
            approved = @('6996218C-58D0-48CE-B6CC-38D06149230A')
            declined = @('6996218c-58d0-48ce-b6cc-38d06149230a')
        }
        Mock Read-GerberConfirmationPrompt { throw 'Approval prompt should not be shown.' }

        $result = Resolve-GerberPluginApproval -PluginModule (Get-GerberApprovalTestPlugin)

        $result | Should -BeTrue
        @($script:configuration.plugins.approved) | Should -Be @('6996218C-58D0-48CE-B6CC-38D06149230A')
        $script:savedConfiguration.plugins.associated.'6996218c-58d0-48ce-b6cc-38d06149230a'.enabled | Should -BeTrue
        Should -Invoke Save-GerberUserConfiguration -Times 1
    }

    It 'does not rewrite an already enabled lifecycle record' {
        $script:configuration.plugins = @{
            approved = @('6996218C-58D0-48CE-B6CC-38D06149230A')
            associated = @{
                '6996218c-58d0-48ce-b6cc-38d06149230a' = @{
                    enabled = $true
                }
            }
        }
        Mock Read-GerberConfirmationPrompt { throw 'Approval prompt should not be shown.' }

        $result = Resolve-GerberPluginApproval -PluginModule (Get-GerberApprovalTestPlugin)

        $result | Should -BeTrue
        Should -Invoke Save-GerberUserConfiguration -Times 0
    }
}
