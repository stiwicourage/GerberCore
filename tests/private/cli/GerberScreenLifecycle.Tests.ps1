# Cross-cutting coverage is intentional here because screen lifecycle behavior depends on
# multiple CLI rendering primitives interacting together, and a single source-mirrored file
# cannot observe the final visible terminal state on its own.
BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    . (Join-Path (Split-Path (Split-Path -Parent $PSScriptRoot) -Parent) 'TestHelpers/GerberVirtualScreenTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Gerber screen lifecycle rendering' {
    BeforeEach {
        $script:virtualScreen = New-GerberVirtualScreenState
        Mock Start-GerberScreen { Clear-GerberVirtualScreen -State $script:virtualScreen }
        Mock Write-GerberScreenLine {
            param([string]$Text = '')
            Write-GerberVirtualScreenLine -State $script:virtualScreen -Text $Text
        }
        Mock Move-GerberConsoleCursorPosition {
            param([int]$Left, [int]$Top)
            Set-GerberVirtualScreenCursor -State $script:virtualScreen -Top $Top -Left $Left
        }
        Mock Write-GerberPromptLine {
            param([pscustomobject]$Line)
            Write-GerberVirtualPromptLine -State $script:virtualScreen -Line $Line
        }
        Mock Write-GerberConsoleLineBreak {
            Add-GerberVirtualScreenLineBreak -State $script:virtualScreen
        }
        Mock Move-GerberPromptCursor {}
        Mock Write-GerberPromptTrace {}
        Mock Get-GerberConsoleBufferWidth { 80 }
        Mock Invoke-GerberMenuLoopIteration { $true }
    }

    It 'clears stale content when a shorter full-screen view replaces a longer one' {
        Show-GerberTextBlock -Title '/pipelines' -Text "release`ntags`nsome-other-entry`nPreview: ..."
        Show-GerberTextBlock -Title '/help' -Text 'Preview: ...'

        (Get-GerberVirtualVisibleLineList -State $script:virtualScreen) | Should -Be @('/help', '', 'Preview: ...')
    }

    It 'removes obsolete suggestion rows when the prompt frame shrinks' {
        $state = @{
            Prompt = ([string][char]0x276F)
            Buffer = '/pip'
            CursorIndex = 4
            SuggestionIndex = 0
            SuggestionList = @(
                [pscustomobject]@{ DisplayText = '/pipelines'; CompletionText = '/pipelines'; PreviewText = 'Open pipelines' }
                [pscustomobject]@{ DisplayText = '/pipelines release'; CompletionText = '/pipelines release'; PreviewText = 'Release pipelines' }
                [pscustomobject]@{ DisplayText = '/pipelines tags'; CompletionText = '/pipelines tags'; PreviewText = 'Pipeline tags' }
            )
            SuggestionNavigationUsed = $true
            RenderedLineCount = 0
            PromptTop = 0
            SuggestionMode = 'Root'
        }

        Show-GerberCommandPrompt -State $state
        $state.SuggestionList = @(
            [pscustomobject]@{ DisplayText = '/pipelines'; CompletionText = '/pipelines'; PreviewText = 'Open pipelines' }
        )
        Show-GerberCommandPrompt -State $state

        (Get-GerberVirtualVisibleLineList -State $script:virtualScreen) | Should -Be @(
            "$([string][char]0x276F) /pip"
            "  $([string][char]0x276F) /pipelines"
            '  Preview: Open pipelines'
        )
        (Get-GerberVirtualScreenLine -State $script:virtualScreen -Row 3) | Should -Be ''
        (Get-GerberVirtualScreenLine -State $script:virtualScreen -Row 4) | Should -Be ''
    }

    It 'removes old suggestion entries when the renderer switches back to the empty state hint' {
        $state = @{
            Prompt = ([string][char]0x276F)
            Buffer = '/'
            CursorIndex = 1
            SuggestionIndex = 0
            SuggestionList = @(
                [pscustomobject]@{ DisplayText = '/help'; CompletionText = '/help'; PreviewText = 'Show help' }
                [pscustomobject]@{ DisplayText = '/tools'; CompletionText = '/tools'; PreviewText = 'Open tools' }
            )
            SuggestionNavigationUsed = $false
            RenderedLineCount = 0
            PromptTop = 0
            SuggestionMode = 'Root'
            EmptyStateHintText = '/ commands · esc back'
        }

        Show-GerberCommandPrompt -State $state
        $state.Buffer = ''
        $state.CursorIndex = 0
        $state.SuggestionList = @()
        Show-GerberCommandPrompt -State $state

        (Get-GerberVirtualVisibleLineList -State $script:virtualScreen) | Should -Be @(
            "$([string][char]0x276F) "
            ''
            '/ commands · esc back'
        )
        (Get-GerberVirtualScreenLine -State $script:virtualScreen -Row 3) | Should -Be ''
    }

    It 'returns from a previous command screen to a clean root screen' {
        Show-GerberTextBlock -Title '/tools base-64' -Text "encode`ndecode`nPreview: ..."

        Show-GerberMenu

        (Get-GerberVirtualVisibleLineList -State $script:virtualScreen) | Should -Be @('Gerber - DevOps Multitool')
    }

    It 'keeps only the latest UI after repeated screen transitions' {
        Show-GerberTextBlock -Title '/repository create' -Text "Project`nTemplate`nOwner team"
        Show-GerberMenu
        Show-GerberTextBlock -Title '/help' -Text "Line 1`nLine 2"
        Show-GerberMenu
        Show-GerberTextBlock -Title '/branch find' -Text "feature/demo`nFound in 1 of 4 repositories."
        Show-GerberMenu

        (Get-GerberVirtualVisibleLineList -State $script:virtualScreen) | Should -Be @('Gerber - DevOps Multitool')
    }
}
