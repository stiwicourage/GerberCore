BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
    $script:selectedMenuMarker = [string][char]0x276F
    $script:selectedPromptStyle = [pscustomobject]@{
        ForegroundColor = [System.ConsoleColor]::Black
        BackgroundColor = [System.ConsoleColor]::White
    }
}

Describe 'Write-GerberStyledPromptText' {
    It 'derives a readable prompt highlight style from current colors' {
        $style = Resolve-GerberDerivedPromptLineStyle -ForegroundColor ([System.ConsoleColor]::Gray) -BackgroundColor ([System.ConsoleColor]::Black)

        $style | Should -Not -BeNullOrEmpty
        $style.BackgroundColor | Should -Not -Be ([System.ConsoleColor]::Black)
        $style.ForegroundColor | Should -Not -Be $style.BackgroundColor
    }

    It 'calculates luminance from console color map entries without property access failures' {
        { Get-GerberColorLuminance -Color ([System.ConsoleColor]::DarkBlue) } | Should -Not -Throw
        (Get-GerberColorLuminance -Color ([System.ConsoleColor]::DarkBlue)) | Should -BeGreaterThan 0
    }

    It 'falls back to reversed prompt colors when a derived style is unavailable' {
        Mock Get-GerberPromptColorPair {
            [pscustomobject]@{
                ForegroundColor = [System.ConsoleColor]::Gray
                BackgroundColor = [System.ConsoleColor]::Black
            }
        }
        Mock Resolve-GerberDerivedPromptLineStyle { $null }

        $style = Resolve-GerberSelectedPromptLineStyle

        $style.ForegroundColor | Should -Be ([System.ConsoleColor]::Black)
        $style.BackgroundColor | Should -Be ([System.ConsoleColor]::Gray)
    }

    It 'falls back to reverse video when host prompt colors are unknown' {
        Mock Get-GerberPromptColorPair {
            [pscustomobject]@{
                ForegroundColor = [System.ConsoleColor]::Gray
                BackgroundColor = [System.ConsoleColor]::Black
            }
        }
        Mock Test-GerberPromptColorPairKnown { $false }
        Mock Test-GerberVirtualTerminalPromptStylingAvailable { $true }

        $style = Resolve-GerberSelectedPromptLineStyle

        $style.Mode | Should -Be 'ReverseVideo'
    }

    It 'uses styled rendering for selected prompt lines when a style is available' {
        Mock Resolve-GerberSelectedPromptLineStyle {
            [pscustomobject]@{
                ForegroundColor = [System.ConsoleColor]::Black
                BackgroundColor = [System.ConsoleColor]::White
            }
        }
        Mock Get-GerberPromptWidth { 20 }
        Mock Write-GerberStyledPromptText {}

        Write-GerberPromptLine -Line ([pscustomobject]@{ Text = "  $($script:selectedMenuMarker) /tools base-64"; IsSelected = $true })

        Should -Invoke Write-GerberStyledPromptText -Times 1
    }

    It 'writes reverse-video ANSI styling without looking up ANSI color codes' {
        Mock Get-GerberConsoleColorAnsiCode { throw 'ANSI color code lookup should not run for reverse video.' }

        {
            Write-GerberAnsiStyledPromptText -Text "  $($script:selectedMenuMarker) /tools base-64" -Style ([pscustomobject]@{
                    Mode = 'ReverseVideo'
                    ForegroundColor = $null
                    BackgroundColor = $null
                })
        } | Should -Not -Throw
    }

    It 'maps console colors to ANSI foreground and background codes' {
        (Get-GerberConsoleColorAnsiCode -Color ([System.ConsoleColor]::DarkBlue) -Kind 'Foreground') | Should -Be 34
        (Get-GerberConsoleColorAnsiCode -Color ([System.ConsoleColor]::DarkBlue) -Kind 'Background') | Should -Be 44
    }

    It 'routes prompt styling to the expected writer for each host mode' -ForEach @(
        @{ SupportsVirtualTerminal = $true; AnsiCalls = 1; RawUiCalls = 0 }
        @{ SupportsVirtualTerminal = $false; AnsiCalls = 0; RawUiCalls = 1 }
    ) {
        Mock Test-GerberVirtualTerminalPromptStylingAvailable { $SupportsVirtualTerminal }
        Mock Write-GerberAnsiStyledPromptText {}
        Mock Write-GerberRawUiStyledPromptText {}

        Write-GerberStyledPromptText -Text "  $($script:selectedMenuMarker) /tools base-64" -Style $script:selectedPromptStyle

        Should -Invoke Write-GerberAnsiStyledPromptText -Times $AnsiCalls
        Should -Invoke Write-GerberRawUiStyledPromptText -Times $RawUiCalls
    }

    It 'returns null style for non-selected prompt lines' {
        (Get-GerberPromptLineStyle -Line ([pscustomobject]@{ IsSelected = $false })) | Should -BeNullOrEmpty
    }

    It 'falls back to the fallback style when the host color pair is null' {
        Mock Get-GerberPromptColorPair { $null }
        Mock Resolve-GerberFallbackPromptLineStyle { [pscustomobject]@{ Mode = 'ReverseVideo' } }

        $result = Resolve-GerberSelectedPromptLineStyle

        $result.Mode | Should -Be 'ReverseVideo'
        Should -Invoke Resolve-GerberFallbackPromptLineStyle -Times 1
    }

    It 'returns the derived style when it is available' {
        Mock Get-GerberPromptColorPair {
            [pscustomobject]@{
                ForegroundColor = [System.ConsoleColor]::Gray
                BackgroundColor = [System.ConsoleColor]::Black
            }
        }
        Mock Test-GerberPromptColorPairKnown { $true }
        Mock Resolve-GerberDerivedPromptLineStyle {
            [pscustomobject]@{
                Mode = 'ColorPair'
                ForegroundColor = [System.ConsoleColor]::Gray
                BackgroundColor = [System.ConsoleColor]::DarkBlue
            }
        }

        $result = Resolve-GerberSelectedPromptLineStyle

        $result.Mode | Should -Be 'ColorPair'
        $result.BackgroundColor | Should -Be ([System.ConsoleColor]::DarkBlue)
    }

    It 'returns null from the fallback style when virtual terminal is not available' {
        Mock Test-GerberVirtualTerminalPromptStylingAvailable { $false }

        (Resolve-GerberFallbackPromptLineStyle) | Should -BeNullOrEmpty
    }

    It 'returns a color pair from the current host colors' {
        $result = Get-GerberPromptColorPair

        $result | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties.Name | Should -Contain 'ForegroundColor'
        $result.PSObject.Properties.Name | Should -Contain 'BackgroundColor'
    }

    It 'returns zero when highlight foreground matches highlight background' {
        $result = Get-GerberPromptStyleScore `
            -HighlightForegroundColor ([System.ConsoleColor]::Black) `
            -HighlightBackgroundColor ([System.ConsoleColor]::Black) `
            -BackgroundColor ([System.ConsoleColor]::White)

        $result | Should -Be 0
    }

    It 'returns a boolean from the VT prompt styling check' {
        (Test-GerberVirtualTerminalPromptStylingAvailable) | Should -BeOfType [bool]
    }

    It 'writes ANSI colored text using foreground and background codes' {
        Mock Get-GerberConsoleColorAnsiCode { 32 }

        {
            Write-GerberAnsiStyledPromptText -Text 'test text' -Style ([pscustomobject]@{
                    Mode = 'ColorPair'
                    ForegroundColor = [System.ConsoleColor]::Green
                    BackgroundColor = [System.ConsoleColor]::Black
                })
        } | Should -Not -Throw
    }

    It 'maps all console colors to the correct ANSI base codes' {
        (Get-GerberConsoleColorAnsiCode -Color ([System.ConsoleColor]::Black) -Kind 'Foreground') | Should -Be 30
        (Get-GerberConsoleColorAnsiCode -Color ([System.ConsoleColor]::DarkRed) -Kind 'Foreground') | Should -Be 31
        (Get-GerberConsoleColorAnsiCode -Color ([System.ConsoleColor]::DarkGreen) -Kind 'Foreground') | Should -Be 32
        (Get-GerberConsoleColorAnsiCode -Color ([System.ConsoleColor]::DarkYellow) -Kind 'Foreground') | Should -Be 33
        (Get-GerberConsoleColorAnsiCode -Color ([System.ConsoleColor]::DarkMagenta) -Kind 'Foreground') | Should -Be 35
        (Get-GerberConsoleColorAnsiCode -Color ([System.ConsoleColor]::DarkCyan) -Kind 'Foreground') | Should -Be 36
        (Get-GerberConsoleColorAnsiCode -Color ([System.ConsoleColor]::Gray) -Kind 'Foreground') | Should -Be 37
        (Get-GerberConsoleColorAnsiCode -Color ([System.ConsoleColor]::DarkGray) -Kind 'Foreground') | Should -Be 90
        (Get-GerberConsoleColorAnsiCode -Color ([System.ConsoleColor]::Red) -Kind 'Foreground') | Should -Be 91
        (Get-GerberConsoleColorAnsiCode -Color ([System.ConsoleColor]::Green) -Kind 'Foreground') | Should -Be 92
        (Get-GerberConsoleColorAnsiCode -Color ([System.ConsoleColor]::Yellow) -Kind 'Foreground') | Should -Be 93
        (Get-GerberConsoleColorAnsiCode -Color ([System.ConsoleColor]::Blue) -Kind 'Foreground') | Should -Be 94
        (Get-GerberConsoleColorAnsiCode -Color ([System.ConsoleColor]::Magenta) -Kind 'Foreground') | Should -Be 95
        (Get-GerberConsoleColorAnsiCode -Color ([System.ConsoleColor]::Cyan) -Kind 'Foreground') | Should -Be 96
        (Get-GerberConsoleColorAnsiCode -Color ([System.ConsoleColor]::White) -Kind 'Foreground') | Should -Be 97
        (Get-GerberConsoleColorAnsiCode -Color ([System.ConsoleColor]::Black) -Kind 'Background') | Should -Be 40
    }

}
