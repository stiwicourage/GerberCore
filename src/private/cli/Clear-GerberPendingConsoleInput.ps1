function Clear-GerberPendingConsoleInput {
    [CmdletBinding()]
    param(
        [switch]$Force
    )

    if (-not $Force -and (Test-GerberPendingEscapeSequencePending)) {
        $pendingKey = Get-GerberEscapeContinuationConsoleKey
        if ($null -ne $pendingKey) {
            Set-GerberPrefetchedConsoleKeyValue -Key $pendingKey
            $script:GerberQueuedEscapeSequencePending = $pendingKey.Key -eq [System.ConsoleKey]::Escape
            return
        }

        $script:GerberQueuedEscapeSequencePending = $false
        return
    }

    while (Test-GerberPendingConsoleInputAvailable) {
        Read-GerberPendingConsoleInputKey | Out-Null
    }
}

function Get-GerberEscapeContinuationConsoleKey {
    [OutputType([System.ConsoleKeyInfo])]
    [CmdletBinding()]
    param(
        [int]$GraceWindowMilliseconds = (Get-GerberMenuEscapeQueueGraceWindowValue)
    )

    if (Test-GerberPendingConsoleInputAvailable) {
        return Read-GerberPendingConsoleInputKey
    }

    if ($GraceWindowMilliseconds -le 0) {
        return $null
    }

    $deadlineTimestampMilliseconds = (Get-GerberMenuEscapeTimestampValue) + $GraceWindowMilliseconds
    while ((Get-GerberMenuEscapeTimestampValue) -lt $deadlineTimestampMilliseconds) {
        Start-Sleep -Milliseconds (Get-GerberMenuEscapeQueuePollIntervalValue)
        if (Test-GerberPendingConsoleInputAvailable) {
            return Read-GerberPendingConsoleInputKey
        }
    }

    return $null
}

function Receive-GerberEscapeContinuationKey {
    [CmdletBinding()]
    param(
        [int]$GraceWindowMilliseconds = (Get-GerberMenuEscapeQueueGraceWindowValue)
    )

    if (Test-GerberPendingRootNavigationRequested) {
        return
    }

    $continuationKey = Get-GerberEscapeContinuationConsoleKey -GraceWindowMilliseconds $GraceWindowMilliseconds
    if ($null -eq $continuationKey) {
        return
    }

    if ($continuationKey.Key -eq [System.ConsoleKey]::Escape) {
        Write-GerberMenuEscapeSequenceStateForKey -Key $continuationKey
        return
    }

    Set-GerberPrefetchedConsoleKeyValue -Key $continuationKey
}

function Test-GerberPendingEscapeSequencePending {
    [OutputType([bool])]
    [CmdletBinding()]
    param()

    if (Test-GerberPendingRootNavigationRequested) {
        return $false
    }

    return $null -ne (Get-GerberLastEscapeTimestampValue)
}

function Test-GerberPendingConsoleInputAvailable {
    [OutputType([bool])]
    [CmdletBinding()]
    param()

    try {
        if (Test-GerberConsoleInputRedirected) {
            return $false
        }

        return (Test-GerberConsoleKeyAvailable)
    } catch {
        return $false
    }
}

function Read-GerberPendingConsoleInputKey {
    [OutputType([System.ConsoleKeyInfo])]
    [CmdletBinding()]
    param()

    return Read-GerberConsoleKey
}

function Test-GerberConsoleInputRedirected {
    [OutputType([bool])]
    [CmdletBinding()]
    param()

    return [Console]::IsInputRedirected
}

function Test-GerberConsoleKeyAvailable {
    [OutputType([bool])]
    [CmdletBinding()]
    param()

    return [Console]::KeyAvailable
}

function Read-GerberConsoleKey {
    [OutputType([System.ConsoleKeyInfo])]
    [CmdletBinding()]
    param()

    return Read-GerberConsoleKeyCore
}

function Read-GerberConsoleKeyCore {
    [OutputType([System.ConsoleKeyInfo])]
    [CmdletBinding()]
    param()

    return [Console]::ReadKey($true)
}

function Get-GerberMenuEscapeQueueGraceWindowValue {
    [OutputType([int])]
    [CmdletBinding()]
    param()

    return 100
}

function Get-GerberMenuEscapeQueuePollIntervalValue {
    [OutputType([int])]
    [CmdletBinding()]
    param()

    return 10
}
