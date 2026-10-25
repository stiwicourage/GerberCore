BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberPromptStateTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
    $script:rootPromptSymbol = [string][char]0x276F
    $script:selectedMenuMarker = [string][char]0x276F
    $script:rootEmptyStateHintText = '/ commands ' + [string][char]0x00B7 + ' esc back'
    $script:rootPromptSuggestionList = @(
        [pscustomobject]@{
            DisplayText = '/help'
            CompletionText = '/help'
            PreviewText = 'Show the built-in command help'
        }
        [pscustomobject]@{
            DisplayText = '/tools'
            CompletionText = '/tools'
            PreviewText = 'Open the interactive tools menu'
        }
    )
    $script:rootActionSuggestionList = @(
        [pscustomobject]@{
            DisplayText = '/help'
            CompletionText = '/help'
            PreviewText = 'Show the built-in command help'
        }
        [pscustomobject]@{
            DisplayText = '/tools create-uuid'
            CompletionText = '/tools create-uuid'
            PreviewText = 'Generate a UUID and copy it to the clipboard when possible'
        }
    )
    $script:selectedPromptStyle = [pscustomobject]@{
        ForegroundColor = [System.ConsoleColor]::Black
        BackgroundColor = [System.ConsoleColor]::White
    }
}

Describe 'Show-GerberCommandPrompt' {
    BeforeEach {
        [Environment]::SetEnvironmentVariable('GERBER_PROMPT_TRACE', $null)
    }

    It 'returns no suggestion lines for an empty suggestion list' {
        $lineList = Format-GerberSuggestionLineList -SuggestionList @() -SelectedIndex 0

        $lineList | Should -Be @()
    }

    It 'returns a single prompt line when there are no suggestions' {
        $lineList = @(Get-GerberCommandPromptLineList -State @{
                Prompt = $script:rootPromptSymbol
                Buffer = ''
                SuggestionIndex = 0
                SuggestionList = @()
                SuggestionNavigationUsed = $false
            })

        $lineList.Text | Should -Be @("$($script:rootPromptSymbol) ")
    }

    It 'shows the root empty-state helper line beneath an empty prompt' {
        $lineList = Get-GerberRootEmptyPromptLineList -PromptSymbol $script:rootPromptSymbol -EmptyStateHintText $script:rootEmptyStateHintText

        $lineList.Text | Should -Be @("$($script:rootPromptSymbol) ", '', $script:rootEmptyStateHintText)
    }

    It 'keeps root slash suggestions visible before arrow navigation starts' {
        $lineList = @(Get-GerberCommandPromptLineList -State (Get-GerberRootPromptState -PromptSymbol $script:rootPromptSymbol -SuggestionList $script:rootPromptSuggestionList))

        ($lineList | Where-Object IsSelected).Text | Should -Be "  $($script:selectedMenuMarker) /help"
        $lineList.Text | Should -Contain "  $($script:selectedMenuMarker) /help"
        $lineList.Text | Should -Contain '    /tools'
    }

    It 'keeps root search suggestions visible before arrow navigation starts' {
        $lineList = @(Get-GerberCommandPromptLineList -State @{
                Prompt = $script:rootPromptSymbol
                Buffer = 'he'
                SuggestionIndex = 0
                SuggestionList = $script:rootActionSuggestionList
                SuggestionNavigationUsed = $false
                SuggestionMode = 'Root'
            })

        ($lineList | Where-Object IsSelected).Text | Should -Be "  $($script:selectedMenuMarker) /help"
        $lineList.Text | Should -Contain "  $($script:selectedMenuMarker) /help"
        $lineList.Text | Should -Contain '    /tools create-uuid'
    }

    It 'highlights the selected suggestion after arrow navigation starts' {
        $lineList = @(Get-GerberCommandPromptLineList -State (Get-GerberRootPromptState -PromptSymbol $script:rootPromptSymbol -SuggestionList $script:rootPromptSuggestionList -SuggestionIndex 1 -SuggestionNavigationUsed $true))

        ($lineList | Where-Object IsSelected).Text | Should -Be "  $($script:selectedMenuMarker) /tools"
    }

    It 'does not highlight suggestions before navigation in submenu mode unless navigation was used' {
        $lineList = @(Get-GerberCommandPromptLineList -State @{
                Prompt = $script:rootPromptSymbol
                Buffer = '/tools '
                SuggestionIndex = 0
                SuggestionList = @(
                    [pscustomobject]@{
                        DisplayText = '/tools create-uuid'
                        CompletionText = '/tools create-uuid'
                        PreviewText = 'Generate a UUID and copy it to the clipboard when possible'
                    }
                    [pscustomobject]@{
                        DisplayText = '/tools base-64'
                        CompletionText = '/tools base-64'
                        PreviewText = 'Open the Base64 text utility'
                    }
                )
                SuggestionNavigationUsed = $false
                SuggestionMode = 'Subcommand'
                SuggestionCommandName = 'tools'
                SuggestionSubcommandTable = [ordered]@{
                    'create-uuid' = 'Generate a UUID and copy it to the clipboard when possible'
                    'base-64' = 'Open the Base64 text utility'
                }
            })

        ($lineList | Where-Object IsSelected) | Should -BeNullOrEmpty
    }

    It 'highlights the first auto-selected submenu suggestion before navigation starts' {
        $lineList = @(Get-GerberCommandPromptLineList -State @{
                Prompt = $script:rootPromptSymbol
                Buffer = '/secrets '
                SuggestionIndex = 0
                SuggestionList = @(
                    [pscustomobject]@{
                        DisplayText = '/secrets list'
                        CompletionText = '/secrets list'
                        PreviewText = 'Show the stored Gerber keys'
                    }
                    [pscustomobject]@{
                        DisplayText = '/secrets get'
                        CompletionText = '/secrets get'
                        PreviewText = 'Reveal a stored Gerber secret after confirmation'
                    }
                )
                SuggestionNavigationUsed = $false
                SuggestionMode = 'Subcommand'
                SuggestionCommandName = 'secrets'
                SuggestionSubcommandTable = [ordered]@{
                    list = 'Show the stored Gerber keys'
                    get = 'Reveal a stored Gerber secret after confirmation'
                }
                InitialBuffer = '/secrets '
                AutoSelectFirstSuggestionOnSubmit = $true
            })

        ($lineList | Where-Object IsSelected).Text | Should -Be "  $($script:selectedMenuMarker) /secrets list"
    }

    It 'highlights the first item in SelectionOnly mode with AutoSelectFirstSuggestionOnSubmit before navigation starts' {
        $lineList = @(Get-GerberCommandPromptLineList -State @{
                Prompt = 'Export or continue'
                Buffer = ''
                SuggestionIndex = 0
                SuggestionList = @(
                    [pscustomobject]@{
                        DisplayText = '1. Export JSON'
                        CompletionText = 'json'
                        PreviewText = 'Export full report as JSON'
                    }
                    [pscustomobject]@{
                        DisplayText = '2. Export CSV'
                        CompletionText = 'csv'
                        PreviewText = 'Export members as CSV'
                    }
                )
                SuggestionNavigationUsed = $false
                SuggestionMode = 'Static'
                InputMode = 'SelectionOnly'
                AutoSelectFirstSuggestionOnSubmit = $true
            })

        ($lineList | Where-Object IsSelected).Text | Should -Be "  $($script:selectedMenuMarker) 1. Export JSON"
    }

    It 'formats named prompts with a colon suffix' {
        (Get-GerberPromptPrefix -Prompt 'Git') | Should -Be 'Git: '
    }

    It 'formats the root prompt without a colon suffix' {
        (Get-GerberPromptPrefix -Prompt $script:rootPromptSymbol) | Should -Be "$($script:rootPromptSymbol) "
    }

    It 'shows submenu hint text when the prompt is still at its initial buffer' {
        $text = Get-GerberPromptInputText -State @{
            Buffer = '/tools '
            InitialBuffer = '/tools '
            PromptHintText = '[create-uuid|base-64]'
        }

        $text | Should -Be '/tools [create-uuid|base-64]'
    }

    It 'hides submenu hint text after the user starts typing' {
        $text = Get-GerberPromptInputText -State @{
            Buffer = '/tools c'
            InitialBuffer = '/tools '
            PromptHintText = '[create-uuid|base-64]'
        }

        $text | Should -Be '/tools c'
    }

    It 'hides the root empty-state helper line after the user starts typing' {
        $lineList = Get-GerberRootEmptyPromptLineList -PromptSymbol $script:rootPromptSymbol -EmptyStateHintText $script:rootEmptyStateHintText -Buffer '/'

        $lineList.Text | Should -Be @("$($script:rootPromptSymbol) /")
    }

    It 'formats autocomplete suggestions with a preview line' {
        $lineList = Format-GerberSuggestionLineList -SuggestionList @(
            [pscustomobject]@{
                DisplayText = '/tools create-uuid'
                CompletionText = '/tools create-uuid'
                PreviewText = 'Generate a UUID and copy it to the clipboard when possible'
            },
            [pscustomobject]@{
                DisplayText = '/tools base-64'
                CompletionText = '/tools base-64'
                PreviewText = 'Open the Base64 text utility'
            }
        ) -SelectedIndex 1

        $lineList.Text | Should -Contain "  $($script:selectedMenuMarker) /tools base-64"
        $lineList.Text | Should -Contain '  Preview: Open the Base64 text utility'
        ($lineList | Where-Object IsSelected).Text | Should -Be "  $($script:selectedMenuMarker) /tools base-64"
    }

    It 'renders all prompt lines by moving the cursor and writing each line' {
        Mock Move-GerberConsoleCursorPosition {}
        Mock Write-GerberPromptLine {}
        Mock Write-GerberConsoleLineBreak {}
        Mock Move-GerberPromptCursor {}
        Mock Write-GerberPromptTrace {}
        $state = @{
            Prompt = $script:rootPromptSymbol
            Buffer = '/help'
            CursorIndex = 5
            SuggestionIndex = 0
            SuggestionList = @()
            SuggestionNavigationUsed = $false
            RenderedLineCount = 0
            PromptTop = 0
        }

        $null = Show-GerberCommandPrompt -State $state

        Should -Invoke Move-GerberConsoleCursorPosition -Times 1
        Should -Invoke Write-GerberPromptLine -Times 1
        Should -Invoke Write-GerberPromptTrace -Times 1 -ParameterFilter { $EventName -eq 'prompt-render' }
        Should -Invoke Move-GerberPromptCursor -Times 1
    }

    It 'returns null style for non-selected prompt lines' {
        $line = [pscustomobject]@{ Text = '  /help'; IsSelected = $false }

        (Get-GerberPromptLineStyle -Line $line) | Should -BeNullOrEmpty
    }

    It 'writes directly to the host for lines without a style' {
        Mock Get-GerberPromptWidth { 80 }
        Mock Resolve-GerberSelectedPromptLineStyle { $null }
        Mock Get-GerberPromptLineStyle { $null }

        { Write-GerberPromptLine -Line ([pscustomobject]@{ Text = '  /help'; IsSelected = $false }) } | Should -Not -Throw
    }

    It 'truncates display text that exceeds the prompt width' {
        $longText = 'a' * 100

        $result = Get-GerberPromptDisplayText -Text $longText -Width 20

        $result.Length | Should -Be 19
    }

    It 'returns an empty display line when the prompt width leaves no writable space' {
        (Get-GerberPromptDisplayText -Text 'abc' -Width 1) | Should -Be ''
    }

    It 'positions the cursor at the correct column after rendering' {
        Mock Get-GerberPromptWidth { 80 }
        Mock Move-GerberConsoleCursorPosition {}
        $state = @{
            Prompt = $script:rootPromptSymbol
            Buffer = '/help'
            CursorIndex = 5
            PromptTop = 0
        }

        Move-GerberPromptCursor -State $state

        Should -Invoke Move-GerberConsoleCursorPosition -Times 1
    }

    It 'returns false from selection continue when InputMode is SelectionOnly' {
        $state = @{
            InputMode = 'SelectionOnly'
            SuggestionList = @([pscustomobject]@{ CompletionText = '/help' })
            Buffer = '/help'
        }

        (Test-GerberPromptSelectionContinue -State $state) | Should -BeFalse
    }

    It 'returns false from selection continue when suggestion list is empty' {
        $state = @{
            SuggestionList = @()
            Buffer = '/help'
        }

        (Test-GerberPromptSelectionContinue -State $state) | Should -BeFalse
    }

    It 'returns true from selection continue when there are multiple suggestions' {
        $state = @{
            SuggestionList = @(
                [pscustomobject]@{ CompletionText = '/help' }
                [pscustomobject]@{ CompletionText = '/tools' }
            )
            Buffer = '/he'
        }

        (Test-GerberPromptSelectionContinue -State $state) | Should -BeTrue
    }

    It 'returns true from selection continue when single suggestion differs from buffer' {
        $state = @{
            SuggestionList = @([pscustomobject]@{ CompletionText = '/help' })
            Buffer = '/he'
        }

        (Test-GerberPromptSelectionContinue -State $state) | Should -BeTrue
    }

    It 'uses the live console width without forcing a larger render width' {
        Mock Get-GerberConsoleBufferWidth { 7 }

        (Get-GerberPromptWidth) | Should -Be 7
    }

    It 'returns null prompt trace width when the console width cannot be read' {
        Mock Get-GerberConsoleBufferWidth { throw 'No buffer width.' }

        (Get-GerberPromptTraceWidthOrNull) | Should -BeNullOrEmpty
    }

    It 'moves to the last line and writes a newline to complete the prompt' {
        Mock Move-GerberConsoleCursorPosition {}
        Mock Write-GerberConsoleLineBreak {}
        Mock Write-GerberPromptTrace {}
        $state = @{
            RenderedLineCount = 3
            PromptTop = 0
            Prompt = $script:rootPromptSymbol
            Buffer = '/help'
            CursorIndex = 5
        }

        { Complete-GerberPrompt -State $state } | Should -Not -Throw
        Should -Invoke Move-GerberConsoleCursorPosition -Times 1
        Should -Invoke Write-GerberConsoleLineBreak -Times 1
        Should -Invoke Write-GerberPromptTrace -Times 1 -ParameterFilter { $EventName -eq 'prompt-complete' }
    }

    It 'reads the current cursor position from the host' {
        { Get-GerberInteractivePromptCursorPosition } | Should -Not -Throw
    }

    It 'reads the current console cursor top row' {
        $result = Get-GerberConsoleCursorTop

        $result | Should -BeOfType [int]
    }

    It 'reads the current console buffer width' {
        $result = Get-GerberConsoleBufferWidth

        $result | Should -BeOfType [int]
    }

    It 'sets the console cursor position without throwing' {
        { Move-GerberConsoleCursorPosition -Left 0 -Top 0 } | Should -Not -Throw
    }

    It 'pads removed lines with empty render lines when the prompt shrinks' {
        Mock Move-GerberConsoleCursorPosition {}
        Mock Write-GerberPromptLine {}
        Mock Move-GerberPromptCursor {}
        $state = @{
            Prompt = $script:rootPromptSymbol
            Buffer = '/help'
            CursorIndex = 5
            SuggestionIndex = 0
            SuggestionList = @()
            SuggestionNavigationUsed = $false
            RenderedLineCount = 3
            PromptTop = 0
        }

        { Show-GerberCommandPrompt -State $state } | Should -Not -Throw
        Should -Invoke Write-GerberPromptLine -Times 3
        $state.RenderedLineCount | Should -Be 1
    }
}
