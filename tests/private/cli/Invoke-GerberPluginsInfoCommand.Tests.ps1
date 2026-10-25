BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Invoke-GerberPluginsInfoCommand' {
    BeforeEach {
        $script:pluginInfoText = $null
        Mock Wait-GerberContinue {}
        Mock Show-GerberTextBlock { $script:pluginInfoText = $Text }
    }

    It 'shows plugin information by GUID' {
        Mock Get-GerberPluginInventory {
            @(
                [pscustomobject]@{
                    Guid = '6996218c-58d0-48ce-b6cc-38d06149230a'
                    Name = 'Gerber.TestPlugin'
                    DisplayName = 'Gerber.TestPlugin'
                    Version = '1.0.0'
                    Description = 'Fixture plugin'
                    Author = 'Fixture Publisher'
                    CompanyName = 'Fixture Company'
                    ModulePath = '/tmp/Gerber.TestPlugin/Gerber.TestPlugin.psd1'
                    ApprovalStatus = 'Approved'
                    IsAssociated = $true
                    IsEnabled = $true
                    State = 'Enabled'
                    Loaded = $true
                    RegisteredNamespaceList = @('example')
                    RegisteredCommandList = @('example')
                }
            )
        }

        Invoke-GerberPluginsInfoCommand -Command ([pscustomobject]@{
                Arguments = @('6996218c-58d0-48ce-b6cc-38d06149230a')
            })

        $script:pluginInfoText | Should -Match 'Plugin: Gerber\.TestPlugin'
        $script:pluginInfoText | Should -Match 'GUID:\s+6996218c-58d0-48ce-b6cc-38d06149230a'
        $script:pluginInfoText | Should -Match 'Approval:\s+Approved'
        $script:pluginInfoText | Should -Match 'Namespaces:\s+/example'
        $script:pluginInfoText | Should -Match 'Commands:\s+/example'
        Should -Invoke Wait-GerberContinue -Times 1
    }

    It 'prompts for a plugin lookup when /plugins info was submitted without an argument' {
        Mock Read-GerberCommand { 'Gerber.TestPlugin' }
        Mock Start-GerberScreen {}
        Mock Write-GerberScreenLine {}
        Mock Get-GerberPluginInventory {
            @(
                [pscustomobject]@{
                    Guid = '6996218c-58d0-48ce-b6cc-38d06149230a'
                    Name = 'Gerber.TestPlugin'
                    DisplayName = 'Gerber.TestPlugin'
                    Version = '1.0.0'
                    Description = 'Fixture plugin'
                    Author = 'Fixture Publisher'
                    CompanyName = 'Fixture Company'
                    ModulePath = '/tmp/Gerber.TestPlugin/Gerber.TestPlugin.psd1'
                    ApprovalStatus = 'Approved'
                    IsAssociated = $false
                    IsEnabled = $true
                    State = 'Discovered'
                    Loaded = $false
                    RegisteredNamespaceList = @()
                    RegisteredCommandList = @()
                }
            )
        }

        Invoke-GerberPluginsInfoCommand -Command ([pscustomobject]@{
                Arguments = @()
            })

        $script:pluginInfoText | Should -Match 'Plugin: Gerber\.TestPlugin'
        Should -Invoke Read-GerberCommand -Times 1 -ParameterFilter {
            $Prompt -eq 'Plugin GUID or unique module name' -and $SuggestionMode -eq 'None'
        }
        Should -Invoke Start-GerberScreen -Times 1 -ParameterFilter { $Name -eq '/plugins info' }
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq '/plugins info' }
    }

    It 'shows plugin information by unique module name' {
        Mock Get-GerberPluginInventory {
            @(
                [pscustomobject]@{
                    Guid = '6996218c-58d0-48ce-b6cc-38d06149230a'
                    Name = 'Gerber.TestPlugin'
                    DisplayName = 'Gerber.TestPlugin'
                    Version = '1.0.0'
                    Description = 'Fixture plugin'
                    Author = 'Fixture Publisher'
                    CompanyName = 'Fixture Company'
                    ModulePath = '/tmp/Gerber.TestPlugin/Gerber.TestPlugin.psd1'
                    ApprovalStatus = 'Approved'
                    IsAssociated = $false
                    IsEnabled = $true
                    State = 'Discovered'
                    Loaded = $false
                    RegisteredNamespaceList = @()
                    RegisteredCommandList = @()
                }
            )
        }

        Invoke-GerberPluginsInfoCommand -Command ([pscustomobject]@{
                Arguments = @('Gerber.TestPlugin')
            })

        $script:pluginInfoText | Should -Match 'Plugin: Gerber\.TestPlugin'
        $script:pluginInfoText | Should -Match 'Associated:\s+No'
        $script:pluginInfoText | Should -Match ('Commands:\s+' + [regex]::Escape([string][char]0x2014))
    }

    It 'shows the declined-state note for a declined plugin' {
        Mock Get-GerberPluginInventory {
            @(
                [pscustomobject]@{
                    Guid = '11111111-2222-3333-4444-555555555555'
                    Name = 'Gerber.Example'
                    DisplayName = 'Gerber.Example'
                    Version = '0.1.0'
                    Description = 'Fixture plugin'
                    Author = 'Fixture Publisher'
                    CompanyName = $null
                    ModulePath = '/tmp/Gerber.Example/Gerber.Example.psd1'
                    ApprovalStatus = 'Declined'
                    IsAssociated = $false
                    IsEnabled = $true
                    State = 'Discovered'
                    Loaded = $false
                    RegisteredNamespaceList = @()
                    RegisteredCommandList = @()
                }
            )
        }

        Invoke-GerberPluginsInfoCommand -Command ([pscustomobject]@{
                Arguments = @('Gerber.Example')
            })

        $script:pluginInfoText | Should -Match 'Approval:\s+Declined'
        $script:pluginInfoText | Should -Match 'will not be loaded or prompt for approval automatically'
    }

    It 'fails clearly for an ambiguous module name' {
        Mock Get-GerberPluginInventory {
            @(
                [pscustomobject]@{
                    Guid = '11111111-2222-3333-4444-555555555555'
                    Name = 'Gerber.Example'
                    DisplayName = 'Gerber.Example'
                    RegisteredNamespaceList = @()
                    RegisteredCommandList = @()
                }
                [pscustomobject]@{
                    Guid = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
                    Name = 'Gerber.Example'
                    DisplayName = 'Gerber.Example'
                    RegisteredNamespaceList = @()
                    RegisteredCommandList = @()
                }
            )
        }

        {
            Invoke-GerberPluginsInfoCommand -Command ([pscustomobject]@{
                    Arguments = @('Gerber.Example')
                })
        } | Should -Throw '*multiple discovered plugins named*'
    }

    It 'fails clearly for an invalid GUID-like input' {
        Mock Get-GerberPluginInventory { @() }

        {
            Invoke-GerberPluginsInfoCommand -Command ([pscustomobject]@{
                    Arguments = @('11111111-2222-not-a-guid')
                })
        } | Should -Throw '*is not a valid GUID*'
    }

    It 'fails clearly for an unknown plugin GUID lookup' {
        Mock Get-GerberPluginInventory { @() }

        {
            Invoke-GerberPluginsInfoCommand -Command ([pscustomobject]@{
                    Arguments = @('6996218c-58d0-48ce-b6cc-38d06149230a')
                })
        } | Should -Throw '*does not know a plugin with GUID*'
    }

    It 'fails clearly for an unknown plugin name lookup' {
        Mock Get-GerberPluginInventory { @() }

        {
            Invoke-GerberPluginsInfoCommand -Command ([pscustomobject]@{
                    Arguments = @('Gerber.MissingPlugin')
                })
        } | Should -Throw '*does not know a plugin named*'
    }

    It 'fails clearly when the prompted plugin lookup is blank' {
        Mock Get-GerberPluginInventory { @() }
        Mock Read-GerberCommand { '' }
        Mock Start-GerberScreen {}
        Mock Write-GerberScreenLine {}

        {
            Invoke-GerberPluginsInfoCommand -Command ([pscustomobject]@{
                    Arguments = @()
                })
        } | Should -Throw '*Specify exactly one plugin GUID or unique module name*'
    }

    It 'returns to the caller when the info view is dismissed with escape in selection mode' {
        Mock Wait-GerberContinue { throw (Get-GerberMenuEscapeException) }

        {
            Show-GerberPluginInfoView `
                -Plugin ([pscustomobject]@{
                    Guid = '6996218c-58d0-48ce-b6cc-38d06149230a'
                    Name = 'Gerber.TestPlugin'
                    DisplayName = 'Gerber.TestPlugin'
                    Version = '1.0.0'
                    Description = 'Fixture plugin'
                    Author = 'Fixture Publisher'
                    CompanyName = 'Fixture Company'
                    ModulePath = '/tmp/Gerber.TestPlugin/Gerber.TestPlugin.psd1'
                    ApprovalStatus = 'Approved'
                    IsAssociated = $true
                    IsEnabled = $true
                    State = 'Enabled'
                    Loaded = $true
                    RegisteredNamespaceList = @('example')
                    RegisteredCommandList = @('example')
                }) `
                -ReturnToSelectionOnEscape
        } | Should -Not -Throw
    }
}
