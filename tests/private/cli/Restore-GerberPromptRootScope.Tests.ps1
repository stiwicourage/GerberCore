BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Restore-GerberPromptRootScope' {
    It 'returns to the root prompt when the submenu prefix is no longer present' {
        $state = @{
            Buffer = '/to'
            SuggestionMode = 'Subcommand'
            SuggestionCommandName = 'tools'
            InitialBuffer = '/tools '
            PromptHintText = '[create-uuid|base-64]'
            SuggestionIndex = 2
        }
        Mock Write-GerberPromptTrace {}

        $result = Restore-GerberPromptRootScope -State $state

        $result | Should -BeTrue
        $state.SuggestionMode | Should -Be 'Root'
        $state.SuggestionCommandName | Should -BeNullOrEmpty
        $state.InitialBuffer | Should -Be ''
        $state.PromptHintText | Should -BeNullOrEmpty
        $state.SuggestionIndex | Should -Be 0
    }

    It 'keeps the submenu prompt when the submenu prefix is still present' {
        $state = @{
            Buffer = '/tools b'
            SuggestionMode = 'Subcommand'
            SuggestionCommandName = 'tools'
            InitialBuffer = '/tools '
            PromptHintText = '[create-uuid|base-64]'
            SuggestionIndex = 1
        }
        Mock Write-GerberPromptTrace {}

        $result = Restore-GerberPromptRootScope -State $state

        $result | Should -BeFalse
        $state.SuggestionMode | Should -Be 'Subcommand'
        $state.SuggestionCommandName | Should -Be 'tools'
        $state.SuggestionIndex | Should -Be 1
    }

    It 'returns false from Test-GerberShouldExitSubcommandScope when InitialBuffer is blank' {
        $state = @{
            Buffer = '/tools'
            SuggestionMode = 'Subcommand'
            InitialBuffer = ''
        }

        (Test-GerberShouldExitSubcommandScope -State $state) | Should -BeFalse
    }
}
