function Restore-GerberPromptRootScope {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    if (-not (Test-GerberShouldExitSubcommandScope -State $State)) {
        return $false
    }

    $State.SuggestionMode = 'Root'
    $State.SuggestionCommandName = $null
    $State.InitialBuffer = ''
    $State.PromptHintText = $null
    $State.SuggestionIndex = 0
    Write-GerberPromptTrace -EventName 'prompt-subcommand-exit' -Data @{
        Buffer = $State.Buffer
    }

    return $true
}

function Test-GerberShouldExitSubcommandScope {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    if ((Get-GerberPromptSuggestionMode -State $State) -ne 'Subcommand') {
        return $false
    }

    $initialBuffer = Get-GerberPromptStateValue -State $State -PropertyName 'InitialBuffer' -DefaultValue ''
    if ([string]::IsNullOrWhiteSpace($initialBuffer)) {
        return $false
    }

    return -not $State.Buffer.StartsWith($initialBuffer, [System.StringComparison]::OrdinalIgnoreCase)
}
