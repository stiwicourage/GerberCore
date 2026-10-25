function Show-GerberRepositoryView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Command
    )

    Show-GerberRegisteredSubcommandMenu `
        -CommandName 'repository' `
        -Command $Command `
        -AutoSelectFirstSuggestionOnSubmit
}
