BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    . (Join-Path (Split-Path (Split-Path -Parent $PSScriptRoot) -Parent) 'TestHelpers/GerberVirtualScreenTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
    function script:Initialize-GerberCheckboxMenuPromptTestHarness {
        param(
            [Parameter(Mandatory)]
            [System.ConsoleKeyInfo[]]$KeyList
        )

        $script:keyIndex = 0
        $script:keyList = @($KeyList)
        Mock Start-GerberScreen {}
        Mock Write-GerberScreenLine {}
        Mock Write-GerberPromptLine {}
        Mock Write-GerberConsoleLineBreak {}
        Mock Get-GerberConsoleCursorTop { 0 }
        Mock Move-GerberConsoleCursorPosition {}
        Mock Read-GerberMenuConsoleKey {
            $key = $script:keyList[$script:keyIndex]
            $script:keyIndex++
            return $key
        }
        Mock Write-GerberPromptTrace {}
        Mock Show-GerberTextBlock {}
        Mock Wait-GerberContinue {}
    }

    function script:New-GerberCheckboxPromptRequest {
        param(
            [string]$Prompt = 'Planned pipelines',
            [string]$ScreenTitle = '/pipelines release application',
            [string]$ScreenText = 'Choose the pipelines to apply.',
            [object[]]$ItemList = @([pscustomobject]@{ Label = 'Sitecore'; Value = 'sitecore' }),
            [string]$EmptySelectionMessage = 'Select at least one pipeline before Apply.',
            [bool]$AllowEmptySelection = $false
        )

        return [pscustomobject]@{
            Prompt                = $Prompt
            ScreenTitle           = $ScreenTitle
            ScreenText            = $ScreenText
            AllowEmptySelection   = $AllowEmptySelection
            ItemList              = @($ItemList)
            EmptySelectionMessage = $EmptySelectionMessage
        }
    }
}

Describe 'Read-GerberCheckboxMenuPrompt' {
    It 'returns a typed result with the selected and deselected items' {
        Initialize-GerberCheckboxMenuPromptTestHarness -KeyList @(
            [System.ConsoleKeyInfo]::new([char]0, [System.ConsoleKey]::DownArrow, $false, $false, $false)
            [System.ConsoleKeyInfo]::new(' ', [System.ConsoleKey]::Spacebar, $false, $false, $false)
            [System.ConsoleKeyInfo]::new([char]13, [System.ConsoleKey]::Enter, $false, $false, $false)
        )

        $result = Read-GerberCheckboxMenuPrompt `
            -PromptRequest (New-GerberCheckboxPromptRequest -ItemList @(
                    [pscustomobject]@{ Label = 'Sitecore'; Value = 'sitecore' }
                    [pscustomobject]@{ Label = 'Unicorn'; Value = 'unicorn' }
                ))

        $result.SelectedValueList | Should -Be @('sitecore')
        $result.DeselectedItemList.Value | Should -Be @('unicorn')
        Should -Invoke Write-GerberPromptTrace -Times 1 -ParameterFilter { $EventName -eq 'checkbox-toggle' }
        Should -Invoke Write-GerberPromptTrace -Times 1 -ParameterFilter { $EventName -eq 'checkbox-submit' }
        Should -Invoke Write-GerberPromptTrace -ParameterFilter {
            $EventName -eq 'checkbox-render' -and
            $Data.ItemCount -eq 2
        }
        Should -Invoke Write-GerberPromptLine -ParameterFilter {
            $Line.Text -eq "$([string][char]0x276F) [$([string][char]0x2714)] Sitecore" -and
            $Line.IsSelected
        }
    }

    It 'ignores Tab safely without opening any recoverable error state' {
        Initialize-GerberCheckboxMenuPromptTestHarness -KeyList @(
            [System.ConsoleKeyInfo]::new([char]9, [System.ConsoleKey]::Tab, $false, $false, $false)
            [System.ConsoleKeyInfo]::new([char]13, [System.ConsoleKey]::Enter, $false, $false, $false)
        )

        $result = Read-GerberCheckboxMenuPrompt `
            -PromptRequest (New-GerberCheckboxPromptRequest)

        $result.SelectedValueList | Should -Be @('sitecore')
        Should -Invoke Write-GerberPromptTrace -Times 1 -ParameterFilter {
            $EventName -eq 'checkbox-key-ignored' -and
            $Data.Key -eq 'Tab'
        }
        Should -Invoke Wait-GerberContinue -Times 0
        Should -Invoke Write-GerberPromptTrace -Times 0 -ParameterFilter { $EventName -eq 'checkbox-empty-submit' }
    }

    It 'blocks Enter when nothing is selected and shows a recoverable error before continuing' {
        Initialize-GerberCheckboxMenuPromptTestHarness -KeyList @(
            [System.ConsoleKeyInfo]::new(' ', [System.ConsoleKey]::Spacebar, $false, $false, $false)
            [System.ConsoleKeyInfo]::new([char]13, [System.ConsoleKey]::Enter, $false, $false, $false)
            [System.ConsoleKeyInfo]::new(' ', [System.ConsoleKey]::Spacebar, $false, $false, $false)
            [System.ConsoleKeyInfo]::new([char]13, [System.ConsoleKey]::Enter, $false, $false, $false)
        )

        $result = Read-GerberCheckboxMenuPrompt `
            -PromptRequest (New-GerberCheckboxPromptRequest)

        $result.SelectedValueList | Should -Be @('sitecore')
        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter {
            $Title -eq '/pipelines release application' -and
            $Text -eq 'Select at least one pipeline before Apply.'
        }
        Should -Invoke Write-GerberPromptTrace -Times 1 -ParameterFilter {
            $EventName -eq 'checkbox-submit-blocked' -and
            $Data.Reason -eq 'NoSelection'
        }
    }

    It 'allows Enter with no selection when the prompt opts in' {
        Initialize-GerberCheckboxMenuPromptTestHarness -KeyList @(
            [System.ConsoleKeyInfo]::new(' ', [System.ConsoleKey]::Spacebar, $false, $false, $false)
            [System.ConsoleKeyInfo]::new([char]13, [System.ConsoleKey]::Enter, $false, $false, $false)
        )

        $result = Read-GerberCheckboxMenuPrompt `
            -PromptRequest (New-GerberCheckboxPromptRequest `
                -Prompt 'Runs to cancel' `
                -ScreenTitle '/pipelines release approve-environment' `
                -ScreenText 'Choose the runs to cancel.' `
                -AllowEmptySelection $true `
                -EmptySelectionMessage 'Select at least one run to cancel before Apply.')

        $result.SelectedValueList | Should -Be @()
        $result.DeselectedItemList.Value | Should -Be @('sitecore')
        Should -Invoke Write-GerberPromptTrace -Times 1 -ParameterFilter { $EventName -eq 'checkbox-submit' }
        Should -Invoke Write-GerberPromptTrace -Times 0 -ParameterFilter { $EventName -eq 'checkbox-submit-blocked' }
    }

    It 'throws the shared escape exception when Escape is pressed' {
        Initialize-GerberCheckboxMenuPromptTestHarness -KeyList @(
            [System.ConsoleKeyInfo]::new([char]27, [System.ConsoleKey]::Escape, $false, $false, $false)
        )

        {
            Read-GerberCheckboxMenuPrompt `
                -PromptRequest (New-GerberCheckboxPromptRequest)
        } | Should -Throw 'Go back to the previous Gerber menu.'
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

        It 'redraws one checkbox menu in place while focus moves' {
            $promptRequest = [pscustomobject]@{
                Prompt      = 'Pipelines'
                ScreenTitle = '/pipelines release application'
                ScreenText  = 'Choose pipelines.'
                ItemList    = @(
                    [pscustomobject]@{ Label = 'Sitecore'; Value = 'sitecore' }
                    [pscustomobject]@{ Label = 'Unicorn'; Value = 'unicorn' }
                )
            }
            $state = Initialize-GerberCheckboxMenuPromptState -ItemList @($promptRequest.ItemList)

            Show-GerberCheckboxMenuPromptScreen -PromptRequest $promptRequest -State $state
            Move-GerberCheckboxMenuFocus -State $state -Direction 'Next'
            Show-GerberCheckboxMenuPromptScreen -PromptRequest $promptRequest -State $state

            (Get-GerberVirtualVisibleLineList -State $script:virtualScreen) | Should -Be @(
                '/pipelines release application'
                ''
                'Choose pipelines.'
                '  [✔] Sitecore'
                '❯ [✔] Unicorn'
                ''
                'Pipelines  Up/Down move | Space toggle | Enter continue | Esc back'
            )
        }

        It 'updates toggle state in place without appending a second checkbox menu' {
            $promptRequest = [pscustomobject]@{
                Prompt   = 'Pipelines'
                ItemList = @(
                    [pscustomobject]@{ Label = 'Sitecore'; Value = 'sitecore' }
                    [pscustomobject]@{ Label = 'Unicorn'; Value = 'unicorn'; IsSelected = $false }
                )
            }
            $state = Initialize-GerberCheckboxMenuPromptState -ItemList @($promptRequest.ItemList)

            Show-GerberCheckboxMenuPromptScreen -PromptRequest $promptRequest -State $state
            Move-GerberCheckboxMenuFocus -State $state -Direction 'Next'
            Select-GerberCheckboxMenuFocusedItemState -State $state
            Show-GerberCheckboxMenuPromptScreen -PromptRequest $promptRequest -State $state

            (Get-GerberVirtualVisibleLineList -State $script:virtualScreen) | Should -Be @(
                '  [✔] Sitecore'
                '❯ [✔] Unicorn'
                ''
                'Pipelines  Up/Down move | Space toggle | Enter continue | Esc back'
            )
            (@(Get-GerberVirtualVisibleLineList -State $script:virtualScreen) | Where-Object { $_ -eq 'Pipelines  Up/Down move | Space toggle | Enter continue | Esc back' }).Count | Should -Be 1
        }
    }
}

Describe 'Read-GerberCheckboxMenuPrompt helpers' {
    It 'initializes checkbox items as selected by default' {
        $state = Initialize-GerberCheckboxMenuPromptState -ItemList @(
            [pscustomobject]@{ Label = 'Sitecore'; Value = 'sitecore' }
            [pscustomobject]@{ Label = 'Unicorn'; Value = 'unicorn'; IsSelected = $false }
        )

        $state.ItemStateList.IsSelected | Should -Be @($true, $false)
        (Get-GerberCheckboxMenuSelectedCount -State $state) | Should -Be 1
    }

    It 'builds focused checkbox item lines with a selected marker and optional description' {
        $lineList = @(Get-GerberCheckboxMenuItemLineList `
                -ItemState ([pscustomobject]@{ Label = 'Sitecore'; IsSelected = $true; Description = 'Prod' }) `
                -Focused $true)

        $lineList[0].Text | Should -Be "$([string][char]0x276F) [$([string][char]0x2714)] Sitecore"
        $lineList[0].IsSelected | Should -BeTrue
        $lineList[1].Text | Should -Be '    Prod'
    }

    It 'resets the checkbox render state after a full-screen interruption' {
        $state = @{
            RenderTop           = 4
            RenderedLineCount   = 3
            ScreenIsInitialized = $true
        }

        Reset-GerberCheckboxMenuPromptRenderState -State $state

        $null -eq $state.RenderTop | Should -BeTrue
        $state.RenderedLineCount | Should -Be 0
        $state.ScreenIsInitialized | Should -BeFalse
    }
}
