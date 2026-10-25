BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Restore-GerberPromptSuggestionSelection' {
    It 'does not reset submenu selection when the submenu scope stays the same' {
        $state = @{
            Buffer = '/tools'
            SuggestionIndex = 2
            SuggestionMode = 'Root'
        }
        Mock Write-GerberPromptTrace {}

        Restore-GerberPromptSuggestionSelection -State $state -PreviousScopeKey 'Root:tools'

        $state.SuggestionIndex | Should -Be 2
    }

    It 'returns a scope key for submenu suggestion input' {
        $scopeKey = Get-GerberPromptSuggestionScopeKey -State @{ SuggestionMode = 'Root' } -InputText '/tools'

        $scopeKey | Should -Be 'Root:tools'
    }

    It 'returns no scope key for incomplete root input' {
        $scopeKey = Get-GerberPromptSuggestionScopeKey -State @{ SuggestionMode = 'Root' } -InputText '/to'

        $scopeKey | Should -BeNullOrEmpty
    }

    It 'returns no scope key for static suggestion mode' {
        $scopeKey = Get-GerberPromptSuggestionScopeKey -State @{ SuggestionMode = 'Static' } -InputText '1'

        $scopeKey | Should -BeNullOrEmpty
    }

    It 'returns false when the resolution name is null' {
        $resolution = [pscustomobject]@{ IsValid = $true; Name = $null; Suggestions = @() }

        (Test-GerberPromptSuggestionScope -Resolution $resolution) | Should -BeFalse
    }
}
