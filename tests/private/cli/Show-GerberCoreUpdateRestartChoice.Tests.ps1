BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Show-GerberCoreUpdateRestartChoice' -Tag 'CoreUpdateRestartUx' {
    BeforeEach {
        Mock Read-GerberNumberedMenuPrompt { 'continue' }
        Mock Write-GerberScreenLine {}
        Mock Write-GerberPromptTrace {}
    }
    AfterEach { Remove-Variable GerberStartupUpdateState -Scope Script -ErrorAction SilentlyContinue }

    Context 'safe standard chooser' {
        It 'defaults to Continue and keeps truthful result and restart instructions visible' {
            @(Show-GerberCoreUpdateRestartChoice -Text 'Installed. Verification: Verified. Recovery: NotRequired.').Count | Should -Be 0
            Should -Invoke Read-GerberNumberedMenuPrompt -Times 1 -ParameterFilter {
                $MenuItemList[0].Value -eq 'continue' -and $MenuItemList[0].Label -eq 'Continue with current version' -and
                $MenuItemList[1].Label -eq 'Exit Gerber' -and $ScreenText -match 'Installed. Verification: Verified' -and
                $ScreenText -match 'does not restart PowerShell' -and $ScreenText -match 'Restart PowerShell, then run gerber'
            }
            $script:GerberStartupUpdateState.Status | Should -Be 'RestartRequired'
        }

        It 'treats local Escape as Continue without swallowing unrelated failures' {
            Mock Read-GerberNumberedMenuPrompt { throw (Get-GerberMenuEscapeException) }
            @(Show-GerberCoreUpdateRestartChoice -Text 'RestartRequired').Count | Should -Be 0
            $script:GerberStartupUpdateState.Message | Should -Match 'Restart PowerShell'
            Mock Read-GerberNumberedMenuPrompt { throw [System.IO.IOException]::new('terminal failure') }
            { Show-GerberCoreUpdateRestartChoice -Text 'RestartRequired' } | Should -Throw '*terminal failure*'
        }

        It 'returns exactly one true exit signal and explains the remaining manual restart' {
            Mock Read-GerberNumberedMenuPrompt { 'exit' }
            @(Show-GerberCoreUpdateRestartChoice -Text 'RestartRequired') | Should -Be @($true)
            Should -Invoke Write-GerberScreenLine -ParameterFilter { $Text -match 'Restart PowerShell.*run gerber' }
            Should -Invoke Write-GerberPromptTrace -ParameterFilter { $EventName -eq 'update-restart-choice' -and $Data.Selection -eq 'exit' }
        }
    }
}
