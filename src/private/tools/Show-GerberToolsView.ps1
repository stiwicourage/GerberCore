function Show-GerberToolsView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Command
    )

    Show-GerberRegisteredSubcommandMenu `
        -CommandName 'tools' `
        -Command $Command `
        -AutoSelectFirstSuggestionOnSubmit
}

function ConvertTo-GerberNestedCommand {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [string[]]$Arguments = @(),

        [int]$SkipCount = 0
    )

    return [pscustomobject]@{
        Arguments = @($Arguments | Select-Object -Skip $SkipCount)
    }
}
