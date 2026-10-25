BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Read-GerberConfirmationPrompt' {
    It 'returns true when the action option is selected' {
        Mock Read-GerberNumberedMenuPrompt { 'action' }

        $result = Read-GerberConfirmationPrompt `
            -ScreenTitle '/secrets list' `
            -Prompt 'Proceed?' `
            -PromptOptionSet (Get-GerberConfirmationPromptOptionSet -ActionLabel 'Install')

        $result | Should -BeTrue
        Should -Invoke Read-GerberNumberedMenuPrompt -Times 1 -ParameterFilter {
            $Prompt -eq 'Proceed?' -and
            $ScreenTitle -eq '/secrets list' -and
            $MenuItemList[0].Label -eq 'Install' -and
            $MenuItemList[0].Value -eq 'action' -and
            $MenuItemList[1].Value -eq 'cancel'
        }
    }

    It 'returns false when the cancel option is selected' {
        Mock Read-GerberNumberedMenuPrompt { 'cancel' }

        $result = Read-GerberConfirmationPrompt -Prompt 'Proceed?'

        $result | Should -BeFalse
    }

    It 'passes the screen title through to the shared numbered prompt helper' {
        Mock Read-GerberNumberedMenuPrompt { 'action' }

        $result = Read-GerberConfirmationPrompt -ScreenTitle '/secrets list' -Prompt 'Proceed?'

        $result | Should -BeTrue
        Should -Invoke Read-GerberNumberedMenuPrompt -Times 1 -ParameterFilter {
            $Prompt -eq 'Proceed?' -and
            $ScreenTitle -eq '/secrets list'
        }
    }

    It 'passes the screen text through to the shared numbered prompt helper' {
        Mock Read-GerberNumberedMenuPrompt { 'action' }

        $result = Read-GerberConfirmationPrompt -ScreenTitle '/secrets list' -ScreenText 'Mismatch details' -Prompt 'Proceed?'

        $result | Should -BeTrue
        Should -Invoke Read-GerberNumberedMenuPrompt -Times 1 -ParameterFilter {
            $Prompt -eq 'Proceed?' -and
            $ScreenTitle -eq '/secrets list' -and
            $ScreenText -eq 'Mismatch details'
        }
    }

    It 'uses custom preview text from the prompt option set' {
        Mock Read-GerberNumberedMenuPrompt { 'action' }

        $null = Read-GerberConfirmationPrompt `
            -Prompt 'Proceed?' `
            -PromptOptionSet (Get-GerberConfirmationPromptOptionSet `
                -ActionLabel 'Install' `
                -CancelLabel 'Back' `
                -ActionPreviewText 'Install the prerequisites.' `
                -CancelPreviewText 'Keep the current setup.')

        Should -Invoke Read-GerberNumberedMenuPrompt -Times 1 -ParameterFilter {
            $MenuItemList[0].PreviewText -eq 'Install the prerequisites.' -and
            $MenuItemList[1].Label -eq 'Back' -and
            $MenuItemList[1].PreviewText -eq 'Keep the current setup.'
        }
    }

    It 'moves cancel to the first menu item when cancel is the default option' {
        Mock Read-GerberNumberedMenuPrompt { 'cancel' }

        $result = Read-GerberConfirmationPrompt `
            -Prompt 'Proceed?' `
            -PromptOptionSet (Get-GerberConfirmationPromptOptionSet `
                -ActionLabel 'Apply' `
                -CancelLabel 'Cancel' `
                -DefaultOption 'cancel')

        $result | Should -BeFalse
        Should -Invoke Read-GerberNumberedMenuPrompt -Times 1 -ParameterFilter {
            $MenuItemList[0].Label -eq 'Cancel' -and
            $MenuItemList[0].Value -eq 'cancel' -and
            $MenuItemList[1].Label -eq 'Apply' -and
            $MenuItemList[1].Value -eq 'action'
        }
    }
}
