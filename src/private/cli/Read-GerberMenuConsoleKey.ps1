function Read-GerberMenuConsoleKey {
    [OutputType([System.ConsoleKeyInfo])]
    [CmdletBinding()]
    param()

    $key = Get-GerberPrefetchedConsoleKeyValue
    if ($null -eq $key) {
        $key = Read-GerberConsoleKey
    }

    Write-GerberMenuEscapeSequenceStateForKey -Key $key
    return $key
}

function Write-GerberMenuEscapeSequenceStateForKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.ConsoleKeyInfo]$Key
    )

    if ($Key.Key -ne [System.ConsoleKey]::Escape) {
        Write-GerberMenuEscapeSequenceReset
        return
    }

    if ((Test-GerberQueuedEscapeSequencePending) -or (Test-GerberEscapeContinuationWindowActive)) {
        $script:GerberPendingRootNavigationRequested = $true
        $script:GerberQueuedEscapeSequencePending = $false
        $script:GerberEscapeContinuationWindowTimestamp = $null
        $script:GerberLastEscapeTimestampMilliseconds = $null
        return
    }

    $timestampMilliseconds = Get-GerberMenuEscapeTimestampValue
    if (Test-GerberMenuEscapeWithinThreshold -TimestampMilliseconds $timestampMilliseconds) {
        $script:GerberPendingRootNavigationRequested = $true
        $script:GerberLastEscapeTimestampMilliseconds = $null
        return
    }

    $script:GerberPendingRootNavigationRequested = $false
    $script:GerberLastEscapeTimestampMilliseconds = $timestampMilliseconds
}

function Test-GerberMenuEscapeWithinThreshold {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [double]$TimestampMilliseconds
    )

    $lastEscapeTimestampMilliseconds = Get-GerberLastEscapeTimestampValue
    if ($null -eq $lastEscapeTimestampMilliseconds) {
        return $false
    }

    return ($TimestampMilliseconds - $lastEscapeTimestampMilliseconds) -le (Get-GerberMenuEscapeThresholdValue)
}

function Test-GerberPendingEscapeSequenceActive {
    [OutputType([bool])]
    [CmdletBinding()]
    param()

    if (Test-GerberPendingRootNavigationRequested) {
        return $false
    }

    $lastEscapeTimestampMilliseconds = Get-GerberLastEscapeTimestampValue
    if ($null -eq $lastEscapeTimestampMilliseconds) {
        return $false
    }

    $elapsedMilliseconds = (Get-GerberMenuEscapeTimestampValue) - $lastEscapeTimestampMilliseconds
    if ($elapsedMilliseconds -le (Get-GerberMenuEscapeThresholdValue)) {
        return $true
    }

    Write-GerberMenuEscapeSequenceReset
    return $false
}

function Write-GerberMenuEscapeSequenceReset {
    [CmdletBinding()]
    param()

    $script:GerberLastEscapeTimestampMilliseconds = $null
    $script:GerberPendingRootNavigationRequested = $false
    $script:GerberQueuedEscapeSequencePending = $false
    $script:GerberEscapeContinuationWindowTimestamp = $null
    $script:GerberPrefetchedConsoleKey = $null
}

function Get-GerberLastEscapeTimestampValue {
    [OutputType([double])]
    [CmdletBinding()]
    param()

    $lastEscapeTimestampVariable = Get-Variable `
        -Name 'GerberLastEscapeTimestampMilliseconds' `
        -Scope Script `
        -ErrorAction SilentlyContinue
    if ($null -eq $lastEscapeTimestampVariable) {
        return $null
    }

    return $lastEscapeTimestampVariable.Value
}

function Test-GerberPendingRootNavigationRequested {
    [OutputType([bool])]
    [CmdletBinding()]
    param()

    $pendingRootNavigationVariable = Get-Variable `
        -Name 'GerberPendingRootNavigationRequested' `
        -Scope Script `
        -ErrorAction SilentlyContinue
    if ($null -eq $pendingRootNavigationVariable) {
        return $false
    }

    return [bool]$pendingRootNavigationVariable.Value
}

function Test-GerberQueuedEscapeSequencePending {
    [OutputType([bool])]
    [CmdletBinding()]
    param()

    $queuedEscapeSequenceVariable = Get-Variable `
        -Name 'GerberQueuedEscapeSequencePending' `
        -Scope Script `
        -ErrorAction SilentlyContinue
    if ($null -eq $queuedEscapeSequenceVariable) {
        return $false
    }

    return [bool]$queuedEscapeSequenceVariable.Value
}

function Set-GerberPrefetchedConsoleKeyValue {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [System.ConsoleKeyInfo]$Key
    )

    $null = $PSCmdlet.ShouldProcess('Set-GerberPrefetchedConsoleKeyValue', 'Invoke')
    $script:GerberPrefetchedConsoleKey = $Key
}

function Get-GerberPrefetchedConsoleKeyValue {
    [OutputType([System.ConsoleKeyInfo])]
    [CmdletBinding()]
    param()

    $prefetchedConsoleKeyVariable = Get-Variable `
        -Name 'GerberPrefetchedConsoleKey' `
        -Scope Script `
        -ErrorAction SilentlyContinue
    if ($null -eq $prefetchedConsoleKeyVariable -or $null -eq $prefetchedConsoleKeyVariable.Value) {
        return $null
    }

    $key = $prefetchedConsoleKeyVariable.Value
    $script:GerberPrefetchedConsoleKey = $null
    return $key
}

function Start-GerberEscapeContinuationWindow {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $null = $PSCmdlet.ShouldProcess('Start-GerberEscapeContinuationWindow', 'Invoke')
    if (Test-GerberPendingEscapeSequencePending) {
        $script:GerberEscapeContinuationWindowTimestamp = Get-GerberMenuEscapeTimestampValue
        return
    }

    $script:GerberEscapeContinuationWindowTimestamp = $null
}

function Test-GerberEscapeContinuationWindowActive {
    [OutputType([bool])]
    [CmdletBinding()]
    param()

    $continuationTimestampVariable = Get-Variable `
        -Name 'GerberEscapeContinuationWindowTimestamp' `
        -Scope Script `
        -ErrorAction SilentlyContinue
    if ($null -eq $continuationTimestampVariable -or $null -eq $continuationTimestampVariable.Value) {
        return $false
    }

    $elapsedMilliseconds = (Get-GerberMenuEscapeTimestampValue) - $continuationTimestampVariable.Value
    if ($elapsedMilliseconds -le (Get-GerberMenuEscapeThresholdValue)) {
        return $true
    }

    $script:GerberEscapeContinuationWindowTimestamp = $null
    return $false
}

function Complete-GerberPendingRootNavigationRequest {
    [CmdletBinding()]
    param()

    Write-GerberMenuEscapeSequenceReset
}

function Get-GerberMenuEscapeThresholdValue {
    [OutputType([int])]
    [CmdletBinding()]
    param()

    return 200
}

function Get-GerberMenuEscapeTimestampValue {
    [OutputType([double])]
    [CmdletBinding()]
    param()

    return [System.Diagnostics.Stopwatch]::GetElapsedTime(0).TotalMilliseconds
}

function Get-GerberPendingEscapeSequenceRemainingMillisecondsValue {
    [OutputType([int])]
    [CmdletBinding()]
    param()

    $lastEscapeTimestampMilliseconds = Get-GerberLastEscapeTimestampValue
    if ($null -eq $lastEscapeTimestampMilliseconds) {
        return 0
    }

    $remainingMilliseconds = (Get-GerberMenuEscapeThresholdValue) - ((Get-GerberMenuEscapeTimestampValue) - $lastEscapeTimestampMilliseconds)
    if ($remainingMilliseconds -le 0) {
        return 0
    }

    return [int][Math]::Ceiling($remainingMilliseconds)
}
