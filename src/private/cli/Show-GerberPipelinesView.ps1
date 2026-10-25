function Show-GerberPipelinesView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Command
    )

    Show-GerberRegisteredSubcommandMenu `
        -CommandName 'pipelines' `
        -Command $Command `
        -AutoSelectFirstSuggestionOnSubmit
}
