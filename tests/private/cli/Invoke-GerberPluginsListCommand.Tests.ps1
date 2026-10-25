BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Invoke-GerberPluginsListCommand' {
    It 'rejects extra arguments for /plugins list' {
        {
            Invoke-GerberPluginsListCommand -Command ([pscustomobject]@{
                    Arguments = @('extra')
                })
        } | Should -Throw "The '/plugins list' command does not accept extra arguments."
    }

    It 'accepts a command object without an Arguments property' {
        Mock Get-GerberPluginInventory { @() }
        Mock Show-GerberTextBlock {}
        Mock Wait-GerberContinue {}

        { Invoke-GerberPluginsListCommand -Command ([pscustomobject]@{ Name = 'plugins list' }) } | Should -Not -Throw
    }

    It 'shows an empty-state message when no plugins are known' {
        Mock Get-GerberPluginInventory { @() }
        Mock Show-GerberTextBlock {}
        Mock Wait-GerberContinue {}

        Invoke-GerberPluginsListCommand

        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter {
            $Title -eq '/plugins list' -and
            $Text -eq 'No plugins are currently discovered or persisted in Gerber user configuration.'
        }
        Should -Invoke Wait-GerberContinue -Times 1
    }

    It 'renders the selection marker in the original plugin table rows' {
        $lineList = Get-GerberPluginListSelectionLineList -State @{
            FocusedIndex = 0
            MenuItemList = @(
                [pscustomobject]@{
                    DisplayName = 'Gerber.TestPlugin'
                    Version = '1.0.0'
                    Guid = '6996218c-58d0-48ce-b6cc-38d06149230a'
                    ApprovalStatus = 'Approved'
                    IsAssociated = $true
                    State = 'Enabled'
                    Loaded = $true
                }
                [pscustomobject]@{
                    DisplayName = 'Gerber.OtherPlugin'
                    Version = '2.0.0'
                    Guid = '11111111-2222-3333-4444-555555555555'
                    ApprovalStatus = 'Declined'
                    IsAssociated = $false
                    State = 'Discovered'
                    Loaded = $false
                }
            )
        }

        $lineList[0].Text | Should -Match '^\s{2}Name'
        $lineList[1].Text | Should -Match '^\s{2}\S+'
        $lineList[2].Text | Should -Match '^\S\sGerber\.TestPlugin'
        $lineList[2].IsSelected | Should -BeTrue
        $lineList[3].Text | Should -Match '^\s{2}Gerber\.OtherPlugin'
        $lineList[3].IsSelected | Should -BeFalse
        $lineList[-1].Text | Should -Be 'Select plugin (Esc to go back):'
    }

    It 'opens info for the focused plugin and returns to the list until escape is pressed' {
        Mock Get-GerberPluginInventory {
            @(
                [pscustomobject]@{
                    DisplayName = 'Gerber.TestPlugin'
                    Version = '1.0.0'
                    Guid = '6996218c-58d0-48ce-b6cc-38d06149230a'
                    ApprovalStatus = 'Approved'
                    IsAssociated = $true
                    State = 'Enabled'
                    Loaded = $true
                }
            )
        }
        Mock Show-GerberPluginListSelectionScreen {}
        $script:keyReadCount = 0
        Mock Read-GerberMenuConsoleKey {
            $script:keyReadCount++
            if ($script:keyReadCount -eq 1) {
                return [System.ConsoleKeyInfo]::new([char]13, [System.ConsoleKey]::Enter, $false, $false, $false)
            }

            return [System.ConsoleKeyInfo]::new([char]27, [System.ConsoleKey]::Escape, $false, $false, $false)
        }
        Mock Show-GerberPluginInfoView {}

        { Invoke-GerberPluginsListCommand } | Should -Not -Throw
        Should -Invoke Show-GerberPluginInfoView -Times 1 -ParameterFilter {
            $Plugin.Guid -eq '6996218c-58d0-48ce-b6cc-38d06149230a' -and
            $ReturnToSelectionOnEscape
        }
    }

    It 'returns cleanly when the interactive plugin list is cancelled' {
        Mock Get-GerberPluginInventory {
            @(
                [pscustomobject]@{
                    DisplayName = 'Gerber.TestPlugin'
                    Version = '1.0.0'
                    Guid = '6996218c-58d0-48ce-b6cc-38d06149230a'
                    ApprovalStatus = 'Approved'
                    IsAssociated = $true
                    State = 'Enabled'
                    Loaded = $true
                }
            )
        }
        Mock Show-GerberPluginListSelectionScreen {}
        Mock Read-GerberMenuConsoleKey { [System.ConsoleKeyInfo]::new([char]27, [System.ConsoleKey]::Escape, $false, $false, $false) }
        Mock Show-GerberPluginInfoView {}

        { Invoke-GerberPluginsListCommand } | Should -Not -Throw
        Should -Invoke Show-GerberPluginInfoView -Times 0
    }

    It 'renders the shared loaded-state text consistently' {
        (Get-GerberPluginLoadedText -Loaded $true) | Should -Be 'Yes'
        (Get-GerberPluginLoadedText -Loaded $false) | Should -Be 'No'
    }
}
