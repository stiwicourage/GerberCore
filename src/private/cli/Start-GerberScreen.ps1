function Start-GerberScreen {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Name = 'Gerber'
    )
    $null = $PSCmdlet.ShouldProcess('Start-GerberScreen', 'Invoke')

    $before = Get-GerberScreenTerminalSnapshot
    Clear-Host
    $after = Get-GerberScreenTerminalSnapshot
    Start-GerberEscapeContinuationWindow

    Write-GerberPromptTrace -EventName 'screen-transition' -Data @{
        Screen          = $Name
        CursorTopBefore = $before.CursorTop
        CursorTopAfter  = $after.CursorTop
        BufferWidth     = Get-GerberFirstScreenSnapshotValue -Primary $after.BufferWidth -Secondary $before.BufferWidth
        WindowWidth     = Get-GerberFirstScreenSnapshotValue -Primary $after.WindowWidth -Secondary $before.WindowWidth
    }
}

function Get-GerberScreenTerminalSnapshot {
    [OutputType([hashtable])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('Get-GerberScreenTerminalSnapshot', 'Invoke')

    return @{
        CursorTop   = Get-GerberScreenSnapshotValue -ScriptBlock { [Console]::CursorTop }
        BufferWidth = Get-GerberScreenSnapshotValue -ScriptBlock { [Console]::BufferWidth }
        WindowWidth = Get-GerberScreenSnapshotValue -ScriptBlock { [Console]::WindowWidth }
    }
}

function Get-GerberScreenSnapshotValue {
    [OutputType([object])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )
    $null = $PSCmdlet.ShouldProcess('Get-GerberScreenSnapshotValue', 'Invoke')

    try {
        return & $ScriptBlock
    } catch {
        return $null
    }
}

function Get-GerberFirstScreenSnapshotValue {
    [OutputType([object])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Primary,

        [AllowNull()]
        [object]$Secondary
    )
    $null = $PSCmdlet.ShouldProcess('Get-GerberFirstScreenSnapshotValue', 'Invoke')

    if ($null -ne $Primary) {
        return $Primary
    }

    return $Secondary
}
