function Get-GerberPromptSelectionIndex {
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [string]$Direction
    )

    if ((Test-GerberPromptSelectionActivation -State $State) -and ($State.SuggestionList.Count -gt 0)) {
        return $State.SuggestionIndex
    }

    return Move-GerberSuggestionSelection -CurrentIndex $State.SuggestionIndex -SuggestionCount $State.SuggestionList.Count -Direction $Direction
}

function Test-GerberPromptSelectionActivation {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    return ((Get-GerberPromptStateValue -State $State -PropertyName 'InputMode' -DefaultValue 'Buffered') -eq 'SelectionOnly') -and -not $State.SuggestionNavigationUsed -and -not (Test-GerberSelectionOnlyAutoFirstSelect -State $State)
}
