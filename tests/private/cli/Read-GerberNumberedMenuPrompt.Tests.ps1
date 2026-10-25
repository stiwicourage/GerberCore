BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    . (Join-Path (Split-Path (Split-Path -Parent $PSScriptRoot) -Parent) 'TestHelpers/GerberVirtualScreenTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Read-GerberNumberedMenuPrompt' {
    It 'reads numbered local menus through arrow-and-enter selection mode' {
        $menuItemList = @(
            [pscustomobject]@{ Number = 1; Label = 'List stored secrets'; Value = '1'; PreviewText = 'Show the currently saved Gerber secret names.' }
            [pscustomobject]@{ Number = 2; Label = 'Open plugin tool'; Value = '2'; PreviewText = 'Run a nested tool provided by an installed plugin.' }
        )
        $script:keyIndex = 0
        $keyList = @(
            [System.ConsoleKeyInfo]::new([char]0, [System.ConsoleKey]::DownArrow, $false, $false, $false)
            [System.ConsoleKeyInfo]::new([char]13, [System.ConsoleKey]::Enter, $false, $false, $false)
        )
        Mock Start-GerberScreen {}
        Mock Show-GerberTextBlock {}
        Mock Write-GerberPromptLine {}
        Mock Write-GerberConsoleLineBreak {}
        Mock Get-GerberConsoleCursorTop { 0 }
        Mock Move-GerberConsoleCursorPosition {}
        Mock Read-GerberMenuConsoleKey {
            $key = $keyList[$script:keyIndex]
            $script:keyIndex++
            return $key
        }
        Mock Write-GerberPromptTrace {}

        $result = Read-GerberNumberedMenuPrompt -Prompt 'Secrets' -MenuItemList $menuItemList

        $result | Should -Be '2'
        Should -Invoke Write-GerberPromptTrace -Times 1 -ParameterFilter {
            $EventName -eq 'numbered-focus' -and
            $Data.Direction -eq 'Next' -and
            $Data.FocusedIndex -eq 1
        }
        Should -Invoke Write-GerberPromptTrace -Times 1 -ParameterFilter {
            $EventName -eq 'numbered-submit' -and
            $Data.Value -eq '2'
        }
        Should -Invoke Write-GerberPromptTrace -ParameterFilter {
            $EventName -eq 'numbered-render' -and
            $Data.ItemCount -eq 2
        }
        Should -Invoke Write-GerberPromptLine -Times 1 -ParameterFilter {
            $Line.Text -eq "  $([string][char]0x276F) 2. Open plugin tool" -and
            $Line.IsSelected
        }
    }

    It 'redraws the current screen through the shared text-block contract when title and text are provided' {
        $menuItemList = @(
            [pscustomobject]@{ Number = 1; Label = 'First'; Value = '1'; PreviewText = 'Choose the first option.' }
        )
        Mock Show-GerberTextBlock {}
        Mock Write-GerberPromptLine {}
        Mock Write-GerberConsoleLineBreak {}
        Mock Get-GerberConsoleCursorTop { 0 }
        Mock Move-GerberConsoleCursorPosition {}
        Mock Read-GerberMenuConsoleKey {
            [System.ConsoleKeyInfo]::new([char]13, [System.ConsoleKey]::Enter, $false, $false, $false)
        }
        Mock Write-GerberPromptTrace {}

        $result = Read-GerberNumberedMenuPrompt `
            -Prompt 'Tools' `
            -ScreenTitle '/tools' `
            -ScreenText 'Tools text' `
            -MenuItemList $menuItemList

        $result | Should -Be '1'
        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter {
            $Title -eq '/tools' -and
            $Text -eq 'Tools text'
        }
    }

    It 'supports single-digit numbered shortcuts without moving focus first' {
        Mock Start-GerberScreen {}
        Mock Write-GerberScreenLine {}
        Mock Write-GerberPromptLine {}
        Mock Write-GerberConsoleLineBreak {}
        Mock Get-GerberConsoleCursorTop { 0 }
        Mock Move-GerberConsoleCursorPosition {}
        Mock Read-GerberMenuConsoleKey {
            [System.ConsoleKeyInfo]::new('2', [System.ConsoleKey]::D2, $false, $false, $false)
        }
        Mock Write-GerberPromptTrace {}

        $result = Read-GerberNumberedMenuPrompt `
            -Prompt 'Confirm' `
            -MenuItemList @(
                [pscustomobject]@{ Number = 1; Label = 'Cancel'; Value = 'cancel'; PreviewText = 'Cancel and go back.' }
                [pscustomobject]@{ Number = 2; Label = 'Apply'; Value = 'action'; PreviewText = 'Apply the selected changes.' }
            )

        $result | Should -Be 'action'
        Should -Invoke Write-GerberPromptTrace -Times 1 -ParameterFilter {
            $EventName -eq 'numbered-submit' -and
            $Data.Value -eq 'action'
        }
    }

    It 'ignores unsupported keys and throws the shared escape exception on Escape' {
        $script:keyIndex = 0
        $keyList = @(
            [System.ConsoleKeyInfo]::new([char]9, [System.ConsoleKey]::Tab, $false, $false, $false)
            [System.ConsoleKeyInfo]::new([char]27, [System.ConsoleKey]::Escape, $false, $false, $false)
        )
        Mock Start-GerberScreen {}
        Mock Write-GerberScreenLine {}
        Mock Write-GerberPromptLine {}
        Mock Write-GerberConsoleLineBreak {}
        Mock Get-GerberConsoleCursorTop { 0 }
        Mock Move-GerberConsoleCursorPosition {}
        Mock Read-GerberMenuConsoleKey {
            $key = $keyList[$script:keyIndex]
            $script:keyIndex++
            return $key
        }
        Mock Write-GerberPromptTrace {}

        {
            Read-GerberNumberedMenuPrompt `
                -Prompt 'Confirm' `
                -MenuItemList @([pscustomobject]@{ Number = 1; Label = 'Cancel'; Value = 'cancel'; PreviewText = 'Cancel and go back.' })
        } | Should -Throw 'Go back to the previous Gerber menu.'

        Should -Invoke Write-GerberPromptTrace -Times 1 -ParameterFilter {
            $EventName -eq 'numbered-key-ignored' -and
            $Data.Key -eq 'Tab'
        }
        Should -Invoke Write-GerberPromptTrace -Times 1 -ParameterFilter {
            $EventName -eq 'numbered-cancel'
        }
    }

    It 'shows a simple screen when the title is present but the screen text is empty' {
        Mock Start-GerberScreen {}
        Mock Write-GerberScreenLine {}

        Show-GerberNumberedMenuPromptScreen -ScreenTitle '/secrets' -ScreenText ''

        Should -Invoke Start-GerberScreen -Times 1 -ParameterFilter { $Name -eq '/secrets' }
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq '/secrets' }
        Should -Invoke Write-GerberScreenLine -Times 2
    }

    Context 'render-region behavior' {
        BeforeEach {
            $script:virtualScreen = New-GerberVirtualScreenState
            Mock Start-GerberScreen { Clear-GerberVirtualScreen -State $script:virtualScreen }
            Mock Write-GerberScreenLine {
                param([string]$Text = '')
                Write-GerberVirtualScreenLine -State $script:virtualScreen -Text $Text
            }
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
            Mock Write-GerberPromptTrace {}
            Mock Get-GerberConsoleBufferWidth { 80 }
        }

        It 'redraws one menu in place while preserving screen content above it' {
            $state = Initialize-GerberNumberedMenuPromptState -MenuItemList @(
                [pscustomobject]@{ Number = 1; Label = 'Project-A'; Value = 'a'; PreviewText = '' }
                [pscustomobject]@{ Number = 2; Label = 'Project-B'; Value = 'b'; PreviewText = '' }
                [pscustomobject]@{ Number = 3; Label = 'Project-C'; Value = 'c'; PreviewText = '' }
            )

            Show-GerberNumberedMenuPrompt -Prompt 'Project' -ScreenTitle '/repository create' -State $state
            Move-GerberNumberedMenuFocus -State $state -Direction 'Next'
            Show-GerberNumberedMenuPrompt -Prompt 'Project' -ScreenTitle '/repository create' -State $state

            $selectedProjectLine = "  $([string][char]0x276F) 2. Project-B"
            (Get-GerberVirtualVisibleLineList -State $script:virtualScreen) | Should -Be @(
                '/repository create'
                ''
                'Project:'
                '    1. Project-A'
                $selectedProjectLine
                '    3. Project-C'
            )
            (@(Get-GerberVirtualVisibleLineList -State $script:virtualScreen) | Where-Object { $_ -eq 'Project:' }).Count | Should -Be 1
        }

        It 'does not append duplicate menu frames after repeated focus changes' {
            $state = Initialize-GerberNumberedMenuPromptState -MenuItemList @(
                [pscustomobject]@{ Number = 1; Label = 'Project-A'; Value = 'a'; PreviewText = '' }
                [pscustomobject]@{ Number = 2; Label = 'Project-B'; Value = 'b'; PreviewText = '' }
                [pscustomobject]@{ Number = 3; Label = 'Project-C'; Value = 'c'; PreviewText = '' }
            )

            Show-GerberNumberedMenuPrompt -Prompt 'Project' -State $state
            Move-GerberNumberedMenuFocus -State $state -Direction 'Next'
            Show-GerberNumberedMenuPrompt -Prompt 'Project' -State $state
            Move-GerberNumberedMenuFocus -State $state -Direction 'Next'
            Show-GerberNumberedMenuPrompt -Prompt 'Project' -State $state
            Move-GerberNumberedMenuFocus -State $state -Direction 'Previous'
            Show-GerberNumberedMenuPrompt -Prompt 'Project' -State $state
            Move-GerberNumberedMenuFocus -State $state -Direction 'Next'
            Show-GerberNumberedMenuPrompt -Prompt 'Project' -State $state
            Move-GerberNumberedMenuFocus -State $state -Direction 'Previous'
            Show-GerberNumberedMenuPrompt -Prompt 'Project' -State $state

            $selectedProjectLine = "  $([string][char]0x276F) 2. Project-B"
            (Get-GerberVirtualVisibleLineList -State $script:virtualScreen) | Should -Be @(
                'Project:'
                '    1. Project-A'
                $selectedProjectLine
                '    3. Project-C'
            )
        }

        It 'clears preview lines when the newly focused item has no preview text' {
            $state = Initialize-GerberNumberedMenuPromptState -MenuItemList @(
                [pscustomobject]@{ Number = 1; Label = 'Project-A'; Value = 'a'; PreviewText = 'Preview A' }
                [pscustomobject]@{ Number = 2; Label = 'Project-B'; Value = 'b'; PreviewText = '' }
            )

            Show-GerberNumberedMenuPrompt -Prompt 'Project' -State $state
            Move-GerberNumberedMenuFocus -State $state -Direction 'Next'
            Show-GerberNumberedMenuPrompt -Prompt 'Project' -State $state

            $selectedProjectLine = "  $([string][char]0x276F) 2. Project-B"
            (Get-GerberVirtualVisibleLineList -State $script:virtualScreen) | Should -Be @(
                'Project:'
                '    1. Project-A'
                $selectedProjectLine
            )
            (Get-GerberVirtualScreenLine -State $script:virtualScreen -Row 3) | Should -Be ''
        }
    }
}

Describe 'Read-GerberNumberedMenuPrompt helpers' {
    It 'wraps focus movement across the menu items' {
        $state = Initialize-GerberNumberedMenuPromptState -MenuItemList @(
            [pscustomobject]@{ Number = 1; Label = 'Cancel'; Value = 'cancel' }
            [pscustomobject]@{ Number = 2; Label = 'Apply'; Value = 'action' }
        )

        Move-GerberNumberedMenuFocus -State $state -Direction 'Previous'
        $state.FocusedIndex | Should -Be 1
        Move-GerberNumberedMenuFocus -State $state -Direction 'Next'
        $state.FocusedIndex | Should -Be 0
    }

    It 'supports first and last focus movement plus item lookup by number' {
        $state = Initialize-GerberNumberedMenuPromptState -MenuItemList @(
            [pscustomobject]@{ Number = 1; Label = 'Cancel'; Value = 'cancel' }
            [pscustomobject]@{ Number = 2; Label = 'Apply'; Value = 'action' }
        )

        Move-GerberNumberedMenuFocus -State $state -Direction 'Last'
        $state.FocusedIndex | Should -Be 1
        Move-GerberNumberedMenuFocus -State $state -Direction 'First'
        $state.FocusedIndex | Should -Be 0
        (Get-GerberNumberedMenuPromptItemByNumberOrNull -MenuItemList $state.MenuItemList -Number '2').Value | Should -Be 'action'
        $null -eq (Get-GerberNumberedMenuPromptItemByNumberOrNull -MenuItemList $state.MenuItemList -Number '3') | Should -BeTrue
    }

    It 'builds prompt lines with a focused item, preview, and empty fallback' {
        $stateWithPreview = Initialize-GerberNumberedMenuPromptState -MenuItemList @(
            [pscustomobject]@{ Number = 1; Label = 'Cancel'; Value = 'cancel'; PreviewText = 'Cancel and go back.' }
        )
        $stateWithoutItems = Initialize-GerberNumberedMenuPromptState -MenuItemList @()

        $lineList = @(Get-GerberNumberedMenuPromptLineList -Prompt 'Confirm' -State $stateWithPreview)
        $emptyItemLineList = @(Get-GerberNumberedMenuItemLineList -State $stateWithoutItems)
        $emptyPreviewLineList = @(Get-GerberNumberedMenuPreviewLineList -State $stateWithoutItems)

        $lineList[0].Text | Should -Be 'Confirm:'
        $lineList[1].Text | Should -Be "  $([string][char]0x276F) 1. Cancel"
        $lineList[2].Text | Should -Be '  Preview: Cancel and go back.'
        $emptyItemLineList[0].Text | Should -Be '  - None'
        $emptyPreviewLineList | Should -Be @()
    }

    It 'returns enter and shortcut selection helpers for matching items only' {
        $state = Initialize-GerberNumberedMenuPromptState -MenuItemList @(
            [pscustomobject]@{ Number = 1; Label = 'Cancel'; Value = 'cancel' }
            [pscustomobject]@{ Number = 2; Label = 'Apply'; Value = 'action' }
        )

        (Get-GerberNumberedMenuEnterSelectionResult -State $state).Value | Should -Be 'cancel'
        (Get-GerberNumberedMenuShortcutSelectionResultOrNull `
            -MenuItemList $state.MenuItemList `
            -Key ([System.ConsoleKeyInfo]::new('2', [System.ConsoleKey]::D2, $false, $false, $false))).Value | Should -Be 'action'
        $null -eq (Get-GerberNumberedMenuShortcutSelectionResultOrNull `
            -MenuItemList $state.MenuItemList `
            -Key ([System.ConsoleKeyInfo]::new('9', [System.ConsoleKey]::D9, $false, $false, $false))) | Should -BeTrue
    }
}
