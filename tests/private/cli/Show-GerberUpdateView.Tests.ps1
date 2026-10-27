BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    foreach ($path in @(
        'cli/Show-GerberUpdateView', 'cli/Read-GerberConfirmationPrompt', 'cli/Wait-GerberContinue',
        'cli/Write-GerberScreenLine', 'cli/Write-GerberPromptTrace', 'cli/Start-GerberScreen',
        'update/Get-GerberCoreUpdateState', 'update/Invoke-GerberCoreUpdateInstall',
        'update/Show-GerberCoreUpdateSummary', 'update/Test-GerberUpdateInteractive', 'update/Format-GerberCoreUpdateOverview'
    )) { . "$root/src/private/$path.ps1" }
}

Describe 'Show-GerberUpdateView' -Tag 'G4A7' {
    BeforeEach {
        $script:state = [pscustomobject]@{
            Status = 'Available'; Name = 'Gerber'; Installed = '0.1.0'; Available = '0.2.0'; Repository = 'Feed'
            Plan = [pscustomobject]@{ RequiresRepositoryTrust = $true; RequiresLicenseAcceptance = $true; Scope = 'AllUsers' }
            Credential = $null; Message = 'An update is available.'
        }
        Mock Get-GerberCoreUpdateState { $script:state }
        Mock Invoke-GerberCoreUpdateInstall { 'Installed and verified. Restart PowerShell before using Gerber again.' }
        Mock Show-GerberCoreUpdateSummary {}
        Mock Test-GerberUpdateInteractive { $true }
        Mock Read-GerberConfirmationPrompt { $false }
        Mock Wait-GerberContinue {}
        Mock Write-GerberScreenLine {}
        Mock Start-GerberScreen {}
        Mock Write-GerberPromptTrace {}
    }

    Context 'explicit Core update workflow' {
        It 'discovers afresh on every invocation and defaults to cancel with explicit trust/license text' {
            Show-GerberUpdateView
            Show-GerberUpdateView
            Should -Invoke Get-GerberCoreUpdateState -Times 2
            Should -Invoke Read-GerberConfirmationPrompt -Times 2 -ParameterFilter {
                $ScreenTitle -eq '/update list' -and
                $PromptOptionSet.DefaultOption -eq 'cancel' -and $ScreenText -match 'trust' -and $ScreenText -match 'license'
            }
            Should -Invoke Invoke-GerberCoreUpdateInstall -Times 0
            Should -Invoke Write-GerberScreenLine -ParameterFilter { $Text -match 'cancelled' }
        }

        It 'installs only the just-discovered live plan after explicit acceptance' {
            Mock Read-GerberConfirmationPrompt { $true }
            Show-GerberUpdateView
            Should -Invoke Invoke-GerberCoreUpdateInstall -Times 1 -ParameterFilter { [object]::ReferenceEquals($State, $script:state) }
            Should -Invoke Write-GerberScreenLine -ParameterFilter { $Text -match 'Restart PowerShell' }
            Should -Invoke Wait-GerberContinue -Times 1
        }

        It 'keeps the compact overview and actual PMU scope visible in the confirmation' {
            Show-GerberUpdateView
            Should -Invoke Read-GerberConfirmationPrompt -Times 1 -ParameterFilter {
                $ScreenText -match 'Installed.*Available.*Repository' -and $ScreenText -match 'Scope: AllUsers'
            }
        }

        It 'shows no-update, discovery failure and no-matching-package outcomes without confirmation' -ForEach @('UpToDate', 'Unavailable', 'NoMatchingPackage', 'RestartRequired') {
            $script:state.Status = $_
            Show-GerberUpdateView
            Should -Invoke Show-GerberCoreUpdateSummary -Times 1
            Should -Invoke Read-GerberConfirmationPrompt -Times 0
            Should -Invoke Invoke-GerberCoreUpdateInstall -Times 0
        }

        It 'never prompts or installs with redirected/noninteractive input' {
            Mock Test-GerberUpdateInteractive { $false }
            Show-GerberUpdateView
            Should -Invoke Read-GerberConfirmationPrompt -Times 0
            Should -Invoke Wait-GerberContinue -Times 0
            Should -Invoke Invoke-GerberCoreUpdateInstall -Times 0
        }

        It 'preserves local Escape cancellation without installing' {
            Mock Read-GerberConfirmationPrompt { throw [System.OperationCanceledException]::new('Esc') }
            { Show-GerberUpdateView } | Should -Throw
            Should -Invoke Invoke-GerberCoreUpdateInstall -Times 0
        }
    }
}
