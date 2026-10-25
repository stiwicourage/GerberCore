BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot

    function script:Read-GerberEscapeSequence {
        param(
            [Parameter(Mandatory)]
            [double[]]$TimestampList
        )

        $script:timestampList = $TimestampList
        Mock Get-GerberMenuEscapeTimestampValue { $script:timestampList[$script:timestampIndex++] }
        $script:timestampIndex = 0
        Mock Read-GerberConsoleKey {
            [System.ConsoleKeyInfo]::new([char]27, [System.ConsoleKey]::Escape, $false, $false, $false)
        }

        $null = Read-GerberMenuConsoleKey
        $null = Read-GerberMenuConsoleKey
    }
}

Describe 'Read-GerberMenuConsoleKey' {
    BeforeEach {
        Write-GerberMenuEscapeSequenceReset
    }

    It 'delegates to the shared console key reader and records the first Escape' {
        Mock Get-GerberMenuEscapeTimestampValue { 1000 }
        Mock Read-GerberConsoleKey { [System.ConsoleKeyInfo]::new([char]27, [System.ConsoleKey]::Escape, $false, $false, $false) }

        (Read-GerberMenuConsoleKey).Key | Should -Be ([System.ConsoleKey]::Escape)
        (Get-GerberLastEscapeTimestampValue) | Should -Be 1000
        (Test-GerberPendingRootNavigationRequested) | Should -BeFalse
    }

    It 'consumes a prefetched console key before reading a new one' {
        Mock Get-GerberMenuEscapeTimestampValue { 1000 }
        Mock Read-GerberConsoleKey { throw 'Should not read a fresh console key.' }
        Set-GerberPrefetchedConsoleKeyValue -Key ([System.ConsoleKeyInfo]::new([char]27, [System.ConsoleKey]::Escape, $false, $false, $false))

        (Read-GerberMenuConsoleKey).Key | Should -Be ([System.ConsoleKey]::Escape)
        (Get-GerberLastEscapeTimestampValue) | Should -Be 1000
        { Get-GerberPrefetchedConsoleKeyValue } | Should -Not -Throw
        (Get-GerberPrefetchedConsoleKeyValue) | Should -BeNullOrEmpty
    }

    It 'requests root navigation on a second Escape within 200 milliseconds' {
        Read-GerberEscapeSequence -TimestampList @(1000, 1200)

        (Test-GerberPendingRootNavigationRequested) | Should -BeTrue
        (Get-GerberLastEscapeTimestampValue) | Should -BeNullOrEmpty
    }

    It 'requests root navigation for a queued second Escape after a screen transition' {
        $script:GerberQueuedEscapeSequencePending = $true
        Mock Get-GerberMenuEscapeTimestampValue { 2000 }
        Mock Read-GerberConsoleKey { [System.ConsoleKeyInfo]::new([char]27, [System.ConsoleKey]::Escape, $false, $false, $false) }

        $null = Read-GerberMenuConsoleKey

        (Test-GerberPendingRootNavigationRequested) | Should -BeTrue
        (Test-GerberQueuedEscapeSequencePending) | Should -BeFalse
    }

    It 'requests root navigation when a prompt continuation window is still active' {
        $script:GerberEscapeContinuationWindowTimestamp = 1500
        Mock Get-GerberMenuEscapeTimestampValue { 1700 }
        Mock Read-GerberConsoleKey { [System.ConsoleKeyInfo]::new([char]27, [System.ConsoleKey]::Escape, $false, $false, $false) }

        $null = Read-GerberMenuConsoleKey

        (Test-GerberPendingRootNavigationRequested) | Should -BeTrue
        $script:GerberEscapeContinuationWindowTimestamp | Should -BeNullOrEmpty
    }

    It 'treats a second Escape after 200 milliseconds as a new single Escape' {
        Read-GerberEscapeSequence -TimestampList @(1000, 1601)

        (Test-GerberPendingRootNavigationRequested) | Should -BeFalse
        (Get-GerberLastEscapeTimestampValue) | Should -Be 1601
    }

    It 'resets the Escape sequence when a non-Escape key is read' {
        Mock Get-GerberMenuEscapeTimestampValue { 1000 }
        $script:keyList = @(
            [System.ConsoleKeyInfo]::new([char]27, [System.ConsoleKey]::Escape, $false, $false, $false)
            [System.ConsoleKeyInfo]::new('a', [System.ConsoleKey]::A, $false, $false, $false)
        )
        $script:keyIndex = 0
        Mock Read-GerberConsoleKey {
            $key = $script:keyList[$script:keyIndex]
            $script:keyIndex++
            return $key
        }

        $null = Read-GerberMenuConsoleKey
        $null = Read-GerberMenuConsoleKey

        (Get-GerberLastEscapeTimestampValue) | Should -BeNullOrEmpty
        (Test-GerberPendingRootNavigationRequested) | Should -BeFalse
    }

    It 'reports an active pending Escape sequence only within the threshold window' {
        Mock Get-GerberMenuEscapeTimestampValue { @(1000, 1200, 1605)[$script:timestampIndex++] }
        $script:timestampIndex = 0
        Write-GerberMenuEscapeSequenceStateForKey -Key ([System.ConsoleKeyInfo]::new([char]27, [System.ConsoleKey]::Escape, $false, $false, $false))

        (Test-GerberPendingEscapeSequenceActive) | Should -BeTrue
        (Test-GerberPendingEscapeSequenceActive) | Should -BeFalse
        (Get-GerberLastEscapeTimestampValue) | Should -BeNullOrEmpty
    }

    It 'clears pending root navigation when the request is completed' {
        $script:GerberPendingRootNavigationRequested = $true
        $script:GerberLastEscapeTimestampMilliseconds = 1000

        Complete-GerberPendingRootNavigationRequest

        (Test-GerberPendingRootNavigationRequested) | Should -BeFalse
        (Get-GerberLastEscapeTimestampValue) | Should -BeNullOrEmpty
    }
}
