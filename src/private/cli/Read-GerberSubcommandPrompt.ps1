function Read-GerberSubcommandPrompt {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$SubcommandTable,

        [switch]$AutoSelectFirstSuggestionOnSubmit
    )

    Start-GerberScreen -Name "/$CommandName"
    Show-GerberHomeScreen

    return Read-GerberCommand `
        -Prompt ([string][char]0x276F) `
        -SuggestionMode 'Subcommand' `
        -InputMode 'Buffered' `
        -PromptContext (ConvertTo-GerberSubcommandPromptContext `
            -CommandName $CommandName `
            -SubcommandTable $SubcommandTable `
            -AutoSelectFirstSuggestionOnSubmit:$AutoSelectFirstSuggestionOnSubmit)
}

function ConvertTo-GerberSubcommandPromptContext {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$SubcommandTable,

        [switch]$AutoSelectFirstSuggestionOnSubmit
    )

    return ConvertTo-GerberCommandPromptContext `
        -SuggestionCommandName $CommandName `
        -SubcommandTable $SubcommandTable `
        -InitialBuffer "/$CommandName " `
        -PromptHintText (Get-GerberSubcommandPromptHintText -SubcommandTable $SubcommandTable) `
        -AutoSelectFirstSuggestionOnSubmit (Test-GerberPromptAutoSelectFirstSuggestion `
            -CommandName $CommandName `
            -AutoSelectFirstSuggestionOnSubmit:$AutoSelectFirstSuggestionOnSubmit)
}

function Get-GerberSubcommandPromptHintText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$SubcommandTable
    )

    if ($SubcommandTable.Count -le 1) {
        return $null
    }

    return '[{0}]' -f ($SubcommandTable.Keys -join '|')
}

function Test-GerberNestedSubcommandPrompt {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName
    )

    return $CommandName.Contains(' ')
}

function Test-GerberPromptAutoSelectFirstSuggestion {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName,

        [switch]$AutoSelectFirstSuggestionOnSubmit
    )

    return $AutoSelectFirstSuggestionOnSubmit -or (Test-GerberNestedSubcommandPrompt -CommandName $CommandName)
}
