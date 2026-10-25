BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'ConvertTo-GerberCommandPromptContext' {
    It 'stores prompt context values for inline submenu prompts' {
        $emptyStateHintText = '/ commands ' + [string][char]0x00B7 + ' esc back'
        $context = ConvertTo-GerberCommandPromptContext `
            -SuggestionCommandName 'tools' `
            -SubcommandTable ([ordered]@{ 'create-uuid' = 'Generate a UUID and copy it to the clipboard when possible' }) `
            -InitialBuffer '/tools ' `
            -PromptHintText '[create-uuid|base-64]' `
            -EmptyStateHintText $emptyStateHintText

        $context.SuggestionCommandName | Should -Be 'tools'
        $context.SubcommandTable.Keys | Should -Be @('create-uuid')
        $context.InitialBuffer | Should -Be '/tools '
        $context.InitialCursorIndex | Should -Be -1
        $context.PromptHintText | Should -Be '[create-uuid|base-64]'
        $context.EmptyStateHintText | Should -Be $emptyStateHintText
    }

    It 'stores an explicit initial cursor index when one is provided' {
        $context = ConvertTo-GerberCommandPromptContext `
            -InitialBuffer 'gerber:<menu>:<action>:<type>:<key>' `
            -InitialCursorIndex 7

        $context.InitialCursorIndex | Should -Be 7
    }

    It 'returns default values for missing context properties' {
        $value = Get-GerberCommandPromptContextValue -PromptContext ([pscustomobject]@{}) -PropertyName 'InitialBuffer' -DefaultValue ''

        $value | Should -Be ''
    }
}
