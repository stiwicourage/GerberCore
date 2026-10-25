BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberPromptSelectionIndex' {
    It 'keeps the first selection in place until a numbered menu is activated without AutoSelectFirstSuggestionOnSubmit' {
        $state = @{
            InputMode = 'SelectionOnly'
            SuggestionNavigationUsed = $false
            AutoSelectFirstSuggestionOnSubmit = $false
            SuggestionIndex = 0
            SuggestionList = @(
                [pscustomobject]@{ DisplayText = '1. First'; CompletionText = '1'; PreviewText = 'First option' }
                [pscustomobject]@{ DisplayText = '2. Second'; CompletionText = '2'; PreviewText = 'Second option' }
            )
        }

        (Get-GerberPromptSelectionIndex -State $state -Direction 'Next') | Should -Be 0
    }

    It 'moves immediately on first arrow press when AutoSelectFirstSuggestionOnSubmit is set' {
        $state = @{
            InputMode = 'SelectionOnly'
            SuggestionNavigationUsed = $false
            AutoSelectFirstSuggestionOnSubmit = $true
            Buffer = ''
            SuggestionIndex = 0
            SuggestionList = @(
                [pscustomobject]@{ DisplayText = '1. First'; CompletionText = '1'; PreviewText = 'First option' }
                [pscustomobject]@{ DisplayText = '2. Second'; CompletionText = '2'; PreviewText = 'Second option' }
            )
        }

        (Get-GerberPromptSelectionIndex -State $state -Direction 'Next') | Should -Be 1
    }

    It 'moves the selection after numbered menu navigation is active' {
        $state = @{
            InputMode = 'SelectionOnly'
            SuggestionNavigationUsed = $true
            SuggestionIndex = 0
            SuggestionList = @(
                [pscustomobject]@{ DisplayText = '1. First'; CompletionText = '1'; PreviewText = 'First option' }
                [pscustomobject]@{ DisplayText = '2. Second'; CompletionText = '2'; PreviewText = 'Second option' }
            )
        }

        (Get-GerberPromptSelectionIndex -State $state -Direction 'Next') | Should -Be 1
    }
}
