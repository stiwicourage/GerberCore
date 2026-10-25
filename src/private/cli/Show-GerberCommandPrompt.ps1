function Show-GerberCommandPrompt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    $lineList = @(Get-GerberCommandPromptLineList -State $State)
    $previousRenderedLineCount = $State.RenderedLineCount
    $lineCount = [Math]::Max($previousRenderedLineCount, $lineList.Count)
    Move-GerberConsoleCursorPosition -Left 0 -Top $State.PromptTop
    for ($index = 0; $index -lt $lineCount; $index++) {
        $line = if ($index -lt $lineList.Count) { $lineList[$index] } else { ConvertTo-GerberPromptRenderLine -Text '' }
        Write-GerberPromptLine -Line $line
        if ($index -lt ($lineCount - 1)) {
            Write-GerberConsoleLineBreak
        }
    }

    $State.RenderedLineCount = $lineList.Count
    Write-GerberPromptTrace -EventName 'prompt-render' -Data @{
        Prompt                 = $State.Prompt
        PromptTop              = $State.PromptTop
        PreviousRenderedLines  = $previousRenderedLineCount
        NewRenderedLines       = $State.RenderedLineCount
        BufferLength           = $State.Buffer.Length
        CursorIndex            = $State.CursorIndex
        SuggestionCount        = $State.SuggestionList.Count
        SuggestionMode         = (Get-GerberPromptSuggestionMode -State $State)
        Width                  = Get-GerberPromptTraceWidthOrNull
    }
    Move-GerberPromptCursor -State $State
}

function Get-GerberCommandPromptLineList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    return @(
        ConvertTo-GerberPromptRenderLine -Text ("{0}{1}" -f (Get-GerberPromptPrefix -Prompt $State.Prompt), (Get-GerberPromptInputText -State $State))
        (Get-GerberPromptSupportingLineList -State $State)
    )
}

function Get-GerberPromptSupportingLineList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    if ($State.SuggestionList.Count -gt 0) {
        return Format-GerberSuggestionLineList `
            -SuggestionList $State.SuggestionList `
            -SelectedIndex $State.SuggestionIndex `
            -HighlightSelected (Test-GerberPromptHighlightsSelectedSuggestion -State $State)
    }

    return Get-GerberPromptEmptyStateHintLineList -State $State
}

function Test-GerberPromptHighlightsSelectedSuggestion {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    if ($State.SuggestionNavigationUsed) {
        return $true
    }

    if (Test-GerberPromptAutoSelectOnSubmit -State $State) {
        return $true
    }

    if (Test-GerberSelectionOnlyAutoFirstSelect -State $State) {
        return $true
    }

    return ((Get-GerberPromptSuggestionMode -State $State) -eq 'Root') -and ($State.Buffer.Length -gt 0)
}

function Get-GerberPromptEmptyStateHintLineList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    if (-not (Test-GerberPromptShowsEmptyStateHint -State $State)) {
        return @()
    }

    return @(
        ConvertTo-GerberPromptRenderLine -Text ''
        ConvertTo-GerberPromptRenderLine -Text (Get-GerberPromptStateValue -State $State -PropertyName 'EmptyStateHintText')
    )
}

function Test-GerberPromptShowsEmptyStateHint {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    $emptyStateHintText = Get-GerberPromptStateValue -State $State -PropertyName 'EmptyStateHintText'
    if ([string]::IsNullOrWhiteSpace($emptyStateHintText) -or ($State.Buffer.Length -gt 0)) {
        return $false
    }

    return (Get-GerberPromptSuggestionMode -State $State) -eq 'Root'
}

function Get-GerberPromptPrefix {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt
    )

    if ($Prompt -eq ([string][char]0x276F)) {
        return ([string][char]0x276F) + ' '
    }

    return "$Prompt`: "
}

function Get-GerberPromptInputText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    $initialBuffer = Get-GerberPromptStateValue -State $State -PropertyName 'InitialBuffer' -DefaultValue ''
    $promptHintText = Get-GerberPromptStateValue -State $State -PropertyName 'PromptHintText'
    if (($State.Buffer -ne $initialBuffer) -or [string]::IsNullOrWhiteSpace($promptHintText)) {
        return $State.Buffer
    }

    return '{0}{1}' -f $State.Buffer, $promptHintText
}

function Format-GerberSuggestionLineList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$SuggestionList,

        [Parameter(Mandatory)]
        [int]$SelectedIndex,

        [bool]$HighlightSelected = $true
    )

    if ($SuggestionList.Count -eq 0) {
        return @()
    }

    $selectedSuggestion = $SuggestionList[$SelectedIndex]
    return @(
        (Get-GerberSuggestionEntryLineList -SuggestionList $SuggestionList -SelectedIndex $SelectedIndex -HighlightSelected $HighlightSelected)
        (ConvertTo-GerberPromptRenderLine -Text ("  Preview: {0}" -f $selectedSuggestion.PreviewText))
    )
}

function Get-GerberSuggestionEntryLineList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$SuggestionList,

        [Parameter(Mandatory)]
        [int]$SelectedIndex,

        [bool]$HighlightSelected = $true
    )

    return @(
        foreach ($index in 0..($SuggestionList.Count - 1)) {
            $prefix = if ($index -eq $SelectedIndex) { [string][char]0x276F } else { ' ' }
            $isSelected = ($index -eq $SelectedIndex) -and $HighlightSelected
            ConvertTo-GerberPromptRenderLine -Text "  $prefix $($SuggestionList[$index].DisplayText)" -IsSelected $isSelected
        }
    )
}

function ConvertTo-GerberPromptRenderLine {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,

        [bool]$IsSelected = $false
    )

    return [pscustomobject]@{
        Text = $Text
        IsSelected = $IsSelected
    }
}

function Write-GerberPromptLine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Line
    )

    $displayText = Get-GerberPromptDisplayText -Text $Line.Text -Width (Get-GerberPromptWidth)
    $style = Get-GerberPromptLineStyle -Line $Line
    if ($null -ne $style) {
        Write-GerberStyledPromptText -Text $displayText -Style $style
        return
    }

    $Host.UI.Write($displayText)
}

function Get-GerberPromptDisplayText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory)]
        [int]$Width
    )

    $displayWidth = [Math]::Max($Width - 1, 0)
    if ($displayWidth -eq 0) {
        return ''
    }

    $displayText = if ($Text.Length -gt $displayWidth) {
        $Text.Substring(0, $displayWidth)
    } else {
        $Text
    }

    return $displayText.PadRight($displayWidth)
}

function Move-GerberPromptCursor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    $promptPrefixLength = (Get-GerberPromptPrefix -Prompt $State.Prompt).Length
    $cursorLeft = [Math]::Min($promptPrefixLength + $State.CursorIndex, [Math]::Max((Get-GerberPromptWidth) - 2, 0))
    Move-GerberConsoleCursorPosition -Left $cursorLeft -Top $State.PromptTop
}

function Test-GerberPromptSelectionContinue {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    if ((Get-GerberPromptStateValue -State $State -PropertyName 'InputMode' -DefaultValue 'Buffered') -eq 'SelectionOnly') {
        return $false
    }

    if ($State.SuggestionList.Count -eq 0) {
        return $false
    }

    if ($State.SuggestionList.Count -ne 1) {
        return $true
    }

    return $State.SuggestionList[0].CompletionText -ne $State.Buffer
}

function Get-GerberPromptWidth {
    [OutputType([int])]
    [CmdletBinding()]
    param()

    return Get-GerberConsoleBufferWidth
}

function Complete-GerberPrompt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    $lineOffset = [Math]::Max($State.RenderedLineCount - 1, 0)
    Move-GerberConsoleCursorPosition -Left 0 -Top ($State.PromptTop + $lineOffset)
    Write-GerberPromptTrace -EventName 'prompt-complete' -Data @{
        Prompt        = $State.Prompt
        PromptTop     = $State.PromptTop
        RenderedLines = $State.RenderedLineCount
        BufferLength  = $State.Buffer.Length
        CursorIndex   = $State.CursorIndex
    }
    Write-GerberConsoleLineBreak
}

function Get-GerberInteractivePromptCursorPosition {
    [OutputType([System.Management.Automation.Host.Coordinates])]
    [CmdletBinding()]
    param()

    return $Host.UI.RawUI.CursorPosition
}

function Get-GerberConsoleCursorTop {
    [OutputType([int])]
    [CmdletBinding()]
    param()

    return [Console]::CursorTop
}

function Get-GerberConsoleBufferWidth {
    [OutputType([int])]
    [CmdletBinding()]
    param()

    return [Console]::BufferWidth
}

function Move-GerberConsoleCursorPosition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Left,

        [Parameter(Mandatory)]
        [int]$Top
    )

    [Console]::SetCursorPosition($Left, $Top)
}

function Get-GerberPromptTraceWidthOrNull {
    [OutputType([object])]
    [CmdletBinding()]
    param()

    try {
        return Get-GerberConsoleBufferWidth
    } catch {
        return $null
    }
}
