function Restore-GerberPromptSuggestionSelection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [string]$PreviousScopeKey
    )

    $currentScopeKey = Get-GerberPromptSuggestionScopeKey -State $State -InputText $State.Buffer
    if ([string]::IsNullOrWhiteSpace($currentScopeKey) -or $currentScopeKey -eq $PreviousScopeKey) {
        return
    }

    $State.SuggestionIndex = 0
    Write-GerberPromptTrace -EventName 'suggestion-reset' -Data @{
        Buffer = $State.Buffer
        PreviousScopeKey = $PreviousScopeKey
        CurrentScopeKey = $currentScopeKey
    }
}

function Get-GerberPromptSuggestionScopeKey {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$InputText
    )

    $suggestionMode = Get-GerberPromptSuggestionMode -State $State
    if ($suggestionMode -eq 'Static') {
        return $null
    }

    $resolution = Resolve-GerberPromptInput `
        -InputText $InputText `
        -SuggestionMode $suggestionMode `
        -SuggestionCommandName (Get-GerberPromptStateValue -State $State -PropertyName 'SuggestionCommandName') `
        -SuggestionSubcommandTable (Get-GerberPromptStateValue -State $State -PropertyName 'SuggestionSubcommandTable')
    if (-not (Test-GerberPromptSuggestionScope -Resolution $resolution)) {
        return $null
    }

    return '{0}:{1}' -f $suggestionMode, $resolution.Name.ToLowerInvariant()
}

function Test-GerberPromptSuggestionScope {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Resolution
    )

    if (-not $Resolution.IsValid) {
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($Resolution.Name)) {
        return $false
    }

    return (Get-GerberCollectionCount -InputObject $Resolution.Suggestions) -gt 0
}
