BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Start-GerberScreen' {
    It 'clears the terminal and traces the screen transition with available diagnostics' {
        Mock Clear-Host {}
        Mock Start-GerberEscapeContinuationWindow {}
        $script:startGerberScreenSnapshotCount = 0
        Mock Get-GerberScreenTerminalSnapshot {
            $script:startGerberScreenSnapshotCount++
            if ($script:startGerberScreenSnapshotCount -eq 1) {
                return @{ CursorTop = 9; BufferWidth = 120; WindowWidth = 100 }
            }

            return @{ CursorTop = 0; BufferWidth = 120; WindowWidth = 100 }
        }
        Mock Write-GerberPromptTrace {}

        Start-GerberScreen -Name '/tools base-64 encode'

        Should -Invoke Clear-Host -Times 1
        Should -Invoke Start-GerberEscapeContinuationWindow -Times 1
        Should -Invoke Write-GerberPromptTrace -Times 1 -ParameterFilter {
            $EventName -eq 'screen-transition' -and
            $Data.Screen -eq '/tools base-64 encode' -and
            $Data.CursorTopBefore -eq 9 -and
            $Data.CursorTopAfter -eq 0 -and
            $Data.BufferWidth -eq 120 -and
            $Data.WindowWidth -eq 100
        }
    }

    It 'keeps the transition trace best-effort when diagnostics are unavailable' {
        Mock Clear-Host {}
        Mock Start-GerberEscapeContinuationWindow {}
        Mock Write-GerberPromptTrace {}

        $script:snapshotCallCount = 0
        Mock Get-GerberScreenTerminalSnapshot {
            $script:snapshotCallCount++
            if ($script:snapshotCallCount -eq 1) {
                return @{ CursorTop = $null; BufferWidth = $null; WindowWidth = 90 }
            }

            return @{ CursorTop = $null; BufferWidth = 80; WindowWidth = $null }
        }

        Start-GerberScreen -Name 'root'

        Should -Invoke Start-GerberEscapeContinuationWindow -Times 1
        Should -Invoke Write-GerberPromptTrace -Times 1 -ParameterFilter {
            $EventName -eq 'screen-transition' -and
            $Data.BufferWidth -eq 80 -and
            $Data.WindowWidth -eq 90
        }
    }

    It 'returns null when a screen snapshot value cannot be read' {
        $value = Get-GerberScreenSnapshotValue -ScriptBlock { throw 'No console.' }

        $value | Should -BeNullOrEmpty
    }
}
