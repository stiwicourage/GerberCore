function New-GerberVirtualScreenState {
    [OutputType([hashtable])]
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $null = $PSCmdlet.ShouldProcess('New-GerberVirtualScreenState', 'Invoke')
    return @{
        LineList   = [System.Collections.Generic.List[string]]::new()
        CursorTop  = 0
        CursorLeft = 0
        WriteTop   = 0
    }
}

function Clear-GerberVirtualScreen {
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    $State.LineList.Clear()
    $State.CursorTop = 0
    $State.CursorLeft = 0
    $State.WriteTop = 0
}

function Set-GerberVirtualScreenCursor {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [int]$Top,

        [Parameter(Mandatory)]
        [int]$Left
    )

    $null = $PSCmdlet.ShouldProcess('Set-GerberVirtualScreenCursor', 'Invoke')
    $State.CursorTop = $Top
    $State.CursorLeft = $Left
    $State.WriteTop = $Top
}

function Write-GerberVirtualScreenLine {
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [string]$Text = ''
    )

    foreach ($line in (Split-GerberVirtualScreenText -Text $Text)) {
        Set-GerberVirtualScreenLine -State $State -Row $State.CursorTop -Text $line
        $State.CursorTop++
        $State.WriteTop = $State.CursorTop
        $State.CursorLeft = 0
    }
}

function Write-GerberVirtualPromptLine {
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [pscustomobject]$Line
    )

    Set-GerberVirtualScreenLine -State $State -Row $State.WriteTop -Text $Line.Text
}

function Add-GerberVirtualScreenLineBreak {
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    $State.WriteTop++
    $State.CursorTop = $State.WriteTop
    $State.CursorLeft = 0
}

function Get-GerberVirtualVisibleLineList {
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    $lineList = @($State.LineList)
    while ($lineList.Count -gt 0 -and [string]::IsNullOrEmpty($lineList[$lineList.Count - 1])) {
        if ($lineList.Count -eq 1) {
            return @()
        }

        $lineList = @($lineList[0..($lineList.Count - 2)])
    }

    return $lineList
}

function Get-GerberVirtualScreenLine {
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [int]$Row
    )

    if ($Row -ge $State.LineList.Count) {
        return ''
    }

    return $State.LineList[$Row]
}

function Split-GerberVirtualScreenText {
    param(
        [string]$Text = ''
    )

    return @($Text -split "\r?\n")
}

function Set-GerberVirtualScreenLine {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [int]$Row,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    $null = $PSCmdlet.ShouldProcess('Set-GerberVirtualScreenLine', 'Invoke')
    while ($State.LineList.Count -le $Row) {
        $null = $State.LineList.Add('')
    }

    $State.LineList[$Row] = $Text
}
