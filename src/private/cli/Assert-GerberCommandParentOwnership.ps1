function Assert-GerberCommandParentOwnership {
    [CmdletBinding()]
    param(
        [AllowNull()][pscustomobject]$Parent,
        [pscustomobject]$Command
    )

    if (Test-GerberCommandParentAccessible -Parent $Parent -Command $Command) {
        return
    }
    throw [System.InvalidOperationException]::new(
        "Gerber cannot register command '$($Command.Name)' because parent '$($Parent.Name)' belongs to another plugin owner '$($Parent.OwnerName)'."
    )
}

function Test-GerberCommandParentAccessible {
    param(
        [AllowNull()][pscustomobject]$Parent,
        [pscustomobject]$Command
    )

    if ($null -eq $Parent) {
        return $true
    }
    return ($Parent.OwnerType -eq 'Core') -or ($Parent.OwnerName -ieq $Command.OwnerName)
}
