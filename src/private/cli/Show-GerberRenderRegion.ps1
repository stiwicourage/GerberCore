function Show-GerberRenderRegion {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$LineList
    )

    $previousRenderedLineCount = Get-GerberRenderRegionRenderedLineCount -State $State
    $renderTop = Resolve-GerberRenderRegionTopOrNull -State $State
    if ($null -eq $renderTop) {
        return Write-GerberRenderRegionFallback -State $State -LineList $LineList -PreviousRenderedLineCount $previousRenderedLineCount
    }

    try {
        $lineCount = [Math]::Max($previousRenderedLineCount, $LineList.Count)
        Move-GerberConsoleCursorPosition -Left 0 -Top $renderTop
        Write-GerberRenderRegionLineList -LineList $LineList -LineCount $lineCount
        $State.RenderedLineCount = $LineList.Count
        return [pscustomobject]@{
            RenderTop             = $renderTop
            PreviousRenderedLines = $previousRenderedLineCount
            NewRenderedLines      = $State.RenderedLineCount
            UsedFallback          = $false
        }
    } catch {
        return Write-GerberRenderRegionFallback -State $State -LineList $LineList -PreviousRenderedLineCount $previousRenderedLineCount
    }
}

function Get-GerberRenderRegionRenderedLineCount {
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    if ($State.ContainsKey('RenderedLineCount')) {
        return [int]$State.RenderedLineCount
    }

    return 0
}

function Resolve-GerberRenderRegionTopOrNull {
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    if ($State.ContainsKey('RenderTop') -and $null -ne $State.RenderTop) {
        return [int]$State.RenderTop
    }

    try {
        $State.RenderTop = Get-GerberConsoleCursorTop
        return [int]$State.RenderTop
    } catch {
        return $null
    }
}

function Write-GerberRenderRegionLineList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$LineList,

        [Parameter(Mandatory)]
        [int]$LineCount
    )

    for ($index = 0; $index -lt $LineCount; $index++) {
        $line = if ($index -lt $LineList.Count) {
            $LineList[$index]
        } else {
            ConvertTo-GerberPromptRenderLine -Text ''
        }
        Write-GerberPromptLine -Line $line
        if ($index -lt ($LineCount - 1)) {
            Write-GerberConsoleLineBreak
        }
    }
}

function Write-GerberRenderRegionFallback {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$LineList,

        [Parameter(Mandatory)]
        [int]$PreviousRenderedLineCount
    )

    Write-GerberRenderRegionLineList -LineList $LineList -LineCount $LineList.Count
    $State.RenderedLineCount = $LineList.Count
    return [pscustomobject]@{
        RenderTop             = if ($State.ContainsKey('RenderTop')) { $State.RenderTop } else { $null }
        PreviousRenderedLines = $PreviousRenderedLineCount
        NewRenderedLines      = $State.RenderedLineCount
        UsedFallback          = $true
    }
}
