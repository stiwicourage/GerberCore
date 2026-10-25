BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Read-GerberSubcommandPrompt' {
    It 'uses the inline submenu prompt design' {
        $subcommandTable = [ordered]@{
            'create-uuid' = 'Generate a UUID and copy it to the clipboard when possible'
            'base-64' = 'Open the Base64 text utility'
        }
        Mock Start-GerberScreen {}
        Mock Show-GerberHomeScreen {}
        Mock Read-GerberCommand { '/tools create-uuid' }

        $result = Read-GerberSubcommandPrompt -CommandName 'tools' -SubcommandTable $subcommandTable

        $result | Should -Be '/tools create-uuid'
        Should -Invoke Start-GerberScreen -Times 1 -ParameterFilter { $Name -eq '/tools' }
        Should -Invoke Show-GerberHomeScreen -Times 1
        Should -Invoke Read-GerberCommand -Times 1 -ParameterFilter {
            $Prompt -eq ([string][char]0x276F) -and
            $SuggestionMode -eq 'Subcommand' -and
            $InputMode -eq 'Buffered' -and
            $PromptContext.SuggestionCommandName -eq 'tools' -and
            $PromptContext.SubcommandTable.Keys -join ',' -eq 'create-uuid,base-64' -and
            $PromptContext.InitialBuffer -eq '/tools ' -and
            $PromptContext.PromptHintText -eq '[create-uuid|base-64]' -and
            $PromptContext.AutoSelectFirstSuggestionOnSubmit -eq $false
        }
    }

    It 'surfaces the default tools action for the top-level tools prompt' {
        $subcommandTable = [ordered]@{
            'create-uuid' = 'Generate a UUID and copy it to the clipboard when possible'
            'base-64' = 'Open the Base64 text utility'
        }

        $context = ConvertTo-GerberSubcommandPromptContext `
            -CommandName 'tools' `
            -SubcommandTable $subcommandTable `
            -AutoSelectFirstSuggestionOnSubmit

        $context.SuggestionCommandName | Should -Be 'tools'
        $context.SubcommandTable.Keys | Should -Be @('create-uuid', 'base-64')
        $context.InitialBuffer | Should -Be '/tools '
        $context.PromptHintText | Should -Be '[create-uuid|base-64]'
        $context.AutoSelectFirstSuggestionOnSubmit | Should -BeTrue
    }

    It 'omits the prompt hint when a submenu exposes only one action' {
        $subcommandTable = [ordered]@{
            'base-64' = 'Open the Base64 text utility'
        }

        (Get-GerberSubcommandPromptHintText -SubcommandTable $subcommandTable) | Should -BeNullOrEmpty
    }

    It 'auto-selects the first suggestion on submit for nested submenu prompts' {
        $subcommandTable = [ordered]@{
            encode = 'Encode UTF-8 text as Base64'
            decode = 'Decode Base64 text into UTF-8 text'
        }

        $context = ConvertTo-GerberSubcommandPromptContext -CommandName 'tools base-64' -SubcommandTable $subcommandTable

        $context.InitialBuffer | Should -Be '/tools base-64 '
        $context.PromptHintText | Should -Be '[encode|decode]'
        $context.AutoSelectFirstSuggestionOnSubmit | Should -BeTrue
    }

    It 'allows top-level submenu prompts to opt into first-suggestion submit behavior' {
        $subcommandTable = [ordered]@{
            list = 'Show the stored Gerber keys'
            get = 'Reveal a stored Gerber secret after confirmation'
        }

        $context = ConvertTo-GerberSubcommandPromptContext `
            -CommandName 'secrets' `
            -SubcommandTable $subcommandTable `
            -AutoSelectFirstSuggestionOnSubmit

        $context.InitialBuffer | Should -Be '/secrets '
        $context.PromptHintText | Should -Be '[list|get]'
        $context.AutoSelectFirstSuggestionOnSubmit | Should -BeTrue
    }

    It 'uses the shared redraw and nested prompt contract for nested tools prompts' -ForEach @(
        @{
            CommandName = 'tools base-64'
            PromptResult = '/tools base-64 decode'
            SubcommandTable = [ordered]@{
                encode = 'Encode UTF-8 text as Base64'
                decode = 'Decode Base64 text into UTF-8 text'
            }
            KeyList = 'encode,decode'
            HintText = '[encode|decode]'
        }
    ) {
        Mock Start-GerberScreen {}
        Mock Show-GerberHomeScreen {}
        Mock Read-GerberCommand { $PromptResult }

        $result = Read-GerberSubcommandPrompt -CommandName $CommandName -SubcommandTable $SubcommandTable

        $result | Should -Be $PromptResult
        Should -Invoke Start-GerberScreen -Times 1 -ParameterFilter { $Name -eq "/$CommandName" }
        Should -Invoke Show-GerberHomeScreen -Times 1
        Should -Invoke Read-GerberCommand -Times 1 -ParameterFilter {
            $Prompt -eq ([string][char]0x276F) -and
            $SuggestionMode -eq 'Subcommand' -and
            $InputMode -eq 'Buffered' -and
            $PromptContext.SuggestionCommandName -eq $CommandName -and
            ($PromptContext.SubcommandTable.Keys -join ',') -eq $KeyList -and
            $PromptContext.InitialBuffer -eq "/$CommandName " -and
            $PromptContext.PromptHintText -eq $HintText -and
            $PromptContext.AutoSelectFirstSuggestionOnSubmit -eq $true
        }
    }

    It 'applies the same redraw contract to future nested submenu prompts' {
        $subcommandTable = [ordered]@{
            first = 'Open the first nested action'
            second = 'Open the second nested action'
        }
        Mock Start-GerberScreen {}
        Mock Show-GerberHomeScreen {}
        Mock Read-GerberCommand { '/future child second' }

        $result = Read-GerberSubcommandPrompt -CommandName 'future child' -SubcommandTable $subcommandTable

        $result | Should -Be '/future child second'
        Should -Invoke Start-GerberScreen -Times 1 -ParameterFilter { $Name -eq '/future child' }
        Should -Invoke Show-GerberHomeScreen -Times 1
        Should -Invoke Read-GerberCommand -Times 1 -ParameterFilter {
            $PromptContext.SuggestionCommandName -eq 'future child' -and
            $PromptContext.InitialBuffer -eq '/future child ' -and
            $PromptContext.PromptHintText -eq '[first|second]' -and
            $PromptContext.AutoSelectFirstSuggestionOnSubmit -eq $true
        }
    }
}
