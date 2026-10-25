BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Show-GerberCreateUuidTool' {
    It 'generates a UUID immediately and repeats when Enter is pressed' {
        Mock Get-GerberUuidValue { @('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222')[$script:uuidCall++] }
        Mock Copy-GerberValueToClipboard { [pscustomobject]@{ Success = $true; Message = 'Copied the result to the clipboard.' } }
        Mock Show-GerberCreateUuidResult {}
        Mock Read-GerberCreateUuidRepeatChoice { @($true, $false)[$script:uuidRepeatCall++] }
        $script:uuidCall = 0
        $script:uuidRepeatCall = 0

        Show-GerberCreateUuidTool

        Should -Invoke Show-GerberCreateUuidResult -Times 1 -ParameterFilter {
            $Result.Value -eq '11111111-1111-1111-1111-111111111111'
        }
        Should -Invoke Show-GerberCreateUuidResult -Times 1 -ParameterFilter {
            $Result.Value -eq '22222222-2222-2222-2222-222222222222'
        }
        Should -Invoke Copy-GerberValueToClipboard -Times 2
    }

    It 'returns to the tools chooser when Escape is selected at the repeat prompt' {
        Mock Get-GerberUuidValue { '11111111-1111-1111-1111-111111111111' }
        Mock Copy-GerberValueToClipboard { [pscustomobject]@{ Success = $true; Message = 'Copied the result to the clipboard.' } }
        Mock Show-GerberCreateUuidResult {}
        Mock Read-GerberCreateUuidRepeatChoice { $false }

        Show-GerberCreateUuidTool

        Should -Invoke Show-GerberCreateUuidResult -Times 1
        Should -Invoke Read-GerberCreateUuidRepeatChoice -Times 1
    }

    It 'shows the UUID result with a UUID-specific clipboard message' {
        Mock Show-GerberTextBlock {}

        Show-GerberCreateUuidResult -Result ([pscustomobject]@{
                Value = '11111111-1111-1111-1111-111111111111'
                ClipboardResult = [pscustomobject]@{
                    Success = $true
                    Message = 'Copied the result to the clipboard.'
                }
            })

        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter {
            $Title -eq '/tools create-uuid' -and
            $Text -match 'UUID' -and
            $Text -match '11111111-1111-1111-1111-111111111111' -and
            $Text -match 'Copied the UUID to the clipboard.'
        }
    }

    It 'uses the repeat prompt text while waiting for another UUID interactively' {
        Mock Clear-GerberPendingConsoleInput {}
        Mock Test-GerberInteractivePromptAvailable { $true }
        Mock Write-GerberCreateUuidRepeatPrompt {}
        Mock Read-GerberContinueKey { [System.ConsoleKeyInfo]::new([char]13, [System.ConsoleKey]::Enter, $false, $false, $false) }

        $result = Read-GerberCreateUuidRepeatChoice

        $result | Should -BeTrue
        Should -Invoke Write-GerberCreateUuidRepeatPrompt -Times 1
    }

    It 'goes back when Escape is pressed at the repeat prompt interactively' {
        Mock Clear-GerberPendingConsoleInput {}
        Mock Test-GerberInteractivePromptAvailable { $true }
        Mock Write-GerberCreateUuidRepeatPrompt {}
        Mock Read-GerberContinueKey { [System.ConsoleKeyInfo]::new([char]27, [System.ConsoleKey]::Escape, $false, $false, $false) }

        (Read-GerberCreateUuidRepeatChoice) | Should -BeFalse
    }

    It 'accepts esc text as back navigation in the fallback repeat prompt' {
        Mock Clear-GerberPendingConsoleInput {}
        Mock Test-GerberInteractivePromptAvailable { $false }
        Mock Read-Host { 'esc' }

        $result = Read-GerberCreateUuidRepeatChoice

        $result | Should -BeFalse
        Should -Invoke Read-Host -Times 1 -ParameterFilter {
            $Prompt -eq 'Press Enter to generate another, or Esc to go back'
        }
    }

    It 'returns a valid UUID string from the generator' {
        $result = Get-GerberUuidValue

        $result | Should -Match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    }

    It 'returns the clipboard failure message when copying was unsuccessful' {
        $result = Get-GerberCreateUuidClipboardMessage -ClipboardResult ([pscustomobject]@{
                Success = $false
                Message = 'Clipboard not available.'
            })

        $result | Should -Be 'Clipboard not available.'
    }

    It 'returns true when the fallback repeat prompt receives empty input' {
        Mock Clear-GerberPendingConsoleInput {}
        Mock Test-GerberInteractivePromptAvailable { $false }
        Mock Read-Host { '' }

        $result = Read-GerberCreateUuidRepeatChoice

        $result | Should -BeTrue
    }

    It 'writes the UUID repeat prompt text without throwing' {
        { Write-GerberCreateUuidRepeatPrompt } | Should -Not -Throw
    }
}
