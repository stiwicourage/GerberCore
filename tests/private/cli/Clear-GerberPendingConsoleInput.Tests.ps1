BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot

    function script:Set-GerberActiveEscapeWindow {
        Mock Get-GerberMenuEscapeTimestampValue { @(1000, 1200)[$script:timestampIndex++] }
        $script:timestampIndex = 0
        Write-GerberMenuEscapeSequenceStateForKey -Key ([System.ConsoleKeyInfo]::new([char]27, [System.ConsoleKey]::Escape, $false, $false, $false))
    }

    function script:Assert-GerberContinuationPrefetch {
        param(
            [Parameter(Mandatory)]
            [System.ConsoleKeyInfo]$Key,

            [Parameter(Mandatory)]
            [bool]$ExpectedQueuedEscapeSequencePending
        )

        Set-GerberActiveEscapeWindow
        Mock Get-GerberEscapeContinuationConsoleKey { $Key }

        Clear-GerberPendingConsoleInput

        Should -Invoke Get-GerberEscapeContinuationConsoleKey -Times 1
        (Test-GerberQueuedEscapeSequencePending) | Should -Be $ExpectedQueuedEscapeSequencePending
        (Get-GerberPrefetchedConsoleKeyValue).Key | Should -Be $Key.Key
    }
}

Describe 'Clear-GerberPendingConsoleInput' {
    BeforeEach {
        Write-GerberMenuEscapeSequenceReset
    }

    It 'drains pending console keys until none remain' {
        Mock Test-GerberPendingConsoleInputAvailable { @($true, $true, $false)[$script:keyAvailableCall++] }
        Mock Read-GerberPendingConsoleInputKey { [System.ConsoleKeyInfo]::new([char]9, [System.ConsoleKey]::Tab, $false, $false, $false) }
        $script:keyAvailableCall = 0

        Clear-GerberPendingConsoleInput

        Should -Invoke Read-GerberPendingConsoleInputKey -Times 2
    }

    It 'does nothing when no pending console input is available' {
        Mock Test-GerberPendingConsoleInputAvailable { $false }
        Mock Read-GerberPendingConsoleInputKey {}

        Clear-GerberPendingConsoleInput

        Should -Invoke Read-GerberPendingConsoleInputKey -Times 0
    }

    It 'prefetches queued Escape input while a single Escape is still within the double-Escape window' {
        Assert-GerberContinuationPrefetch `
            -Key ([System.ConsoleKeyInfo]::new([char]27, [System.ConsoleKey]::Escape, $false, $false, $false)) `
            -ExpectedQueuedEscapeSequencePending $true
    }

    It 'prefetches non-Escape input without discarding it during an active Escape window' {
        Assert-GerberContinuationPrefetch `
            -Key ([System.ConsoleKeyInfo]::new('a', [System.ConsoleKey]::A, $false, $false, $false)) `
            -ExpectedQueuedEscapeSequencePending $false
    }

    It 'forces a queue clear when requested for root navigation cleanup' {
        $script:pendingAvailableCallCount = 0
        Mock Test-GerberPendingConsoleInputAvailable {
            $script:pendingAvailableCallCount++
            return $script:pendingAvailableCallCount -eq 1
        }
        Mock Read-GerberPendingConsoleInputKey {
            [System.ConsoleKeyInfo]::new('a', [System.ConsoleKey]::A, $false, $false, $false)
        }

        Clear-GerberPendingConsoleInput -Force

        Should -Invoke Read-GerberPendingConsoleInputKey -Times 1
    }

    It 'treats any pending escape sequence as continuation-eligible even after the threshold' {
        $script:GerberLastEscapeTimestampMilliseconds = 1000
        Mock Get-GerberEscapeContinuationConsoleKey { $null }

        Clear-GerberPendingConsoleInput

        (Test-GerberQueuedEscapeSequencePending) | Should -BeFalse
    }

    It 'polls briefly for a transition key when none is immediately available' {
        $script:availabilityCallCount = 0
        $script:timestampIndex = 0
        Mock Get-GerberMenuEscapeTimestampValue { @(1000, 1000, 1005, 1015, 1025)[$script:timestampIndex++] }
        Mock Test-GerberPendingConsoleInputAvailable {
            $script:availabilityCallCount++
            return $script:availabilityCallCount -ge 3
        }
        Mock Read-GerberPendingConsoleInputKey {
            [System.ConsoleKeyInfo]::new([char]27, [System.ConsoleKey]::Escape, $false, $false, $false)
        }
        Mock Start-Sleep {}

        (Get-GerberEscapeContinuationConsoleKey).Key | Should -Be ([System.ConsoleKey]::Escape)

        Should -Invoke Start-Sleep -Times 2
        Should -Invoke Read-GerberPendingConsoleInputKey -Times 1
    }

    It 'promotes a continuation Escape to a root-navigation request before the next screen consumes it' {
        Set-GerberActiveEscapeWindow
        Mock Get-GerberEscapeContinuationConsoleKey {
            [System.ConsoleKeyInfo]::new([char]27, [System.ConsoleKey]::Escape, $false, $false, $false)
        }

        Receive-GerberEscapeContinuationKey

        (Test-GerberPendingRootNavigationRequested) | Should -BeTrue
    }

    It 'preserves non-Escape continuation input for the next prompt read' {
        Mock Get-GerberEscapeContinuationConsoleKey {
            [System.ConsoleKeyInfo]::new('a', [System.ConsoleKey]::A, $false, $false, $false)
        }

        Receive-GerberEscapeContinuationKey

        (Test-GerberPendingRootNavigationRequested) | Should -BeFalse
        (Get-GerberPrefetchedConsoleKeyValue).Key | Should -Be ([System.ConsoleKey]::A)
    }

    It 'reports no pending input when console input is redirected' {
        Mock Test-GerberConsoleInputRedirected { $true }
        Mock Test-GerberConsoleKeyAvailable { $true }

        (Test-GerberPendingConsoleInputAvailable) | Should -BeFalse
    }

    It 'delegates to Test-GerberConsoleKeyAvailable when console is not redirected and no key is waiting' {
        Mock Test-GerberConsoleInputRedirected { $false }
        Mock Test-GerberConsoleKeyAvailable { $false }

        (Test-GerberPendingConsoleInputAvailable) | Should -BeFalse
    }

    It 'returns true when console is not redirected and a key is available' {
        Mock Test-GerberConsoleInputRedirected { $false }
        Mock Test-GerberConsoleKeyAvailable { $true }

        (Test-GerberPendingConsoleInputAvailable) | Should -BeTrue
    }

    It 'reports no pending input when console access throws' {
        Mock Test-GerberConsoleInputRedirected { throw 'No console' }

        (Test-GerberPendingConsoleInputAvailable) | Should -BeFalse
    }

    It 'reads the next pending console key through the shared console wrapper' {
        Mock Read-GerberConsoleKey { [System.ConsoleKeyInfo]::new([char]9, [System.ConsoleKey]::Tab, $false, $false, $false) }

        (Read-GerberPendingConsoleInputKey).Key | Should -Be ([System.ConsoleKey]::Tab)
    }

    It 'delegates raw console reads through the console key core helper' {
        Mock Read-GerberConsoleKeyCore { [System.ConsoleKeyInfo]::new([char]27, [System.ConsoleKey]::Escape, $false, $false, $false) }

        (Read-GerberConsoleKey).Key | Should -Be ([System.ConsoleKey]::Escape)
    }
}
