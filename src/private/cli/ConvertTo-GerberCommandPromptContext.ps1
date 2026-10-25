function ConvertTo-GerberCommandPromptContext {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [string]$SuggestionCommandName,

        [System.Collections.IDictionary]$SubcommandTable,

        [AllowEmptyCollection()]
        [object[]]$StaticSuggestionList = @(),

        [AllowEmptyString()]
        [string]$InitialBuffer = '',

        [int]$InitialCursorIndex = -1,

        [string]$PromptHintText,

        [string]$EmptyStateHintText,

        [bool]$AutoSelectFirstSuggestionOnSubmit = $false
    )

    return [pscustomobject]@{
        SuggestionCommandName = $SuggestionCommandName
        SubcommandTable = $SubcommandTable
        StaticSuggestionList = @($StaticSuggestionList)
        InitialBuffer = $InitialBuffer
        InitialCursorIndex = $InitialCursorIndex
        PromptHintText = $PromptHintText
        EmptyStateHintText = $EmptyStateHintText
        AutoSelectFirstSuggestionOnSubmit = $AutoSelectFirstSuggestionOnSubmit
    }
}

function Get-GerberCommandPromptContextValue {
    [OutputType([object])]
    [CmdletBinding()]
    param(
        [pscustomobject]$PromptContext,

        [Parameter(Mandatory)]
        [string]$PropertyName,

        [object]$DefaultValue = $null
    )

    if (($null -eq $PromptContext) -or ($PromptContext.PSObject.Properties.Match($PropertyName).Count -eq 0)) {
        return $DefaultValue
    }

    return $PromptContext.$PropertyName
}
