function Show-GerberPluginsView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Command
    )

    Show-GerberRegisteredSubcommandMenu `
        -CommandName 'plugins' `
        -Command $Command `
        -AutoSelectFirstSuggestionOnSubmit
}
