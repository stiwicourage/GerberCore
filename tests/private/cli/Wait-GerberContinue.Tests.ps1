BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Wait-GerberContinue' {
    It 'uses Read-Host when the interactive prompt is unavailable' {
        Mock Clear-GerberPendingConsoleInput {}
        Mock Test-GerberInteractivePromptAvailable { $false }
        Mock Read-Host { '' }

        Wait-GerberContinue

        Should -Invoke Read-Host -Times 1 -ParameterFilter { $Prompt -eq 'Press Enter to continue' }
    }

    It 'waits for Enter in the interactive continue prompt' {
        Mock Write-GerberContinuePrompt {}
        Mock Read-GerberContinueKey { [System.ConsoleKeyInfo]::new([char]13, [System.ConsoleKey]::Enter, $false, $false, $false) }

        { Wait-GerberInteractiveContinue } | Should -Not -Throw
    }

    It 'treats Escape in the interactive continue prompt as back navigation' {
        Mock Write-GerberContinuePrompt {}
        Mock Read-GerberContinueKey { [System.ConsoleKeyInfo]::new([char]27, [System.ConsoleKey]::Escape, $false, $false, $false) }

        { Wait-GerberInteractiveContinue } | Should -Throw 'Go back to the previous Gerber menu.'
    }

    It 'reads continue keys through the menu console wrapper' {
        Mock Read-GerberMenuConsoleKey { [System.ConsoleKeyInfo]::new([char]13, [System.ConsoleKey]::Enter, $false, $false, $false) }

        (Read-GerberContinueKey).Key | Should -Be ([System.ConsoleKey]::Enter)
    }

    It 'routes to the interactive continue path when the prompt is available' {
        Mock Clear-GerberPendingConsoleInput {}
        Mock Test-GerberInteractivePromptAvailable { $true }
        Mock Wait-GerberInteractiveContinue {}

        Wait-GerberContinue

        Should -Invoke Wait-GerberInteractiveContinue -Times 1
    }

    It 'writes the continue prompt text without throwing' {
        { Write-GerberContinuePrompt } | Should -Not -Throw
    }
}
