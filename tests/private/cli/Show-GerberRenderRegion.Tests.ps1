BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    . (Join-Path (Split-Path (Split-Path -Parent $PSScriptRoot) -Parent) 'TestHelpers/GerberVirtualScreenTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Show-GerberRenderRegion' {
    BeforeEach {
        $script:virtualScreen = New-GerberVirtualScreenState
        Mock Get-GerberConsoleCursorTop { $script:virtualScreen.CursorTop }
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
        Mock Get-GerberConsoleBufferWidth { 80 }
    }

    It 'rewrites a shorter frame without leaving stale lines behind' {
        $state = @{
            RenderTop         = $null
            RenderedLineCount = 0
        }

        $firstResult = Show-GerberRenderRegion -State $state -LineList @(
            (ConvertTo-GerberPromptRenderLine -Text 'Project:')
            (ConvertTo-GerberPromptRenderLine -Text '  ❯ 1. Project-A' -IsSelected $true)
            (ConvertTo-GerberPromptRenderLine -Text '    2. Project-B')
            (ConvertTo-GerberPromptRenderLine -Text '  Preview: Choose Project-A')
        )
        $secondResult = Show-GerberRenderRegion -State $state -LineList @(
            (ConvertTo-GerberPromptRenderLine -Text 'Project:')
            (ConvertTo-GerberPromptRenderLine -Text '    1. Project-A')
            (ConvertTo-GerberPromptRenderLine -Text '  ❯ 2. Project-B' -IsSelected $true)
        )

        $firstResult.UsedFallback | Should -BeFalse
        $secondResult.UsedFallback | Should -BeFalse
        (Get-GerberVirtualVisibleLineList -State $script:virtualScreen) | Should -Be @(
            'Project:'
            '    1. Project-A'
            '  ❯ 2. Project-B'
        )
        (Get-GerberVirtualScreenLine -State $script:virtualScreen -Row 3) | Should -Be ''
    }

    It 'falls back safely when the cursor cannot be repositioned' {
        $state = @{
            RenderTop         = 0
            RenderedLineCount = 1
        }
        Mock Move-GerberConsoleCursorPosition { throw 'No cursor.' }

        $result = Show-GerberRenderRegion -State $state -LineList @(
            (ConvertTo-GerberPromptRenderLine -Text 'Project:')
        )

        $result.UsedFallback | Should -BeTrue
        (Get-GerberVirtualVisibleLineList -State $script:virtualScreen) | Should -Be @('Project:')
    }
}
