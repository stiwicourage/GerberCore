function Show-GerberListView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Command
    )

    Show-GerberRegisteredSubcommandMenu `
        -CommandName 'list' `
        -Command $Command `
        -AutoSelectFirstSuggestionOnSubmit
}
