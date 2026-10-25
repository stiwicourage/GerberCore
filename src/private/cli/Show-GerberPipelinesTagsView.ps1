function Show-GerberPipelinesTagsView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Command
    )

    $currentCommand = $Command
    while ($true) {
        $subcommand = Read-GerberPipelinesTagsSubcommand -Command $currentCommand
        switch ($subcommand) {
            '' {
                return
            }
            'delete' {
                Invoke-GerberPipelineTagDelete
                $currentCommand = [pscustomobject]@{ Arguments = [string[]]@() }
                continue
            }
            'update' {
                Invoke-GerberPipelineTagUpdate
                $currentCommand = [pscustomobject]@{ Arguments = [string[]]@() }
                continue
            }
            default {
                throw [System.ArgumentException]::new(
                    "Unknown pipelines tags subcommand '$subcommand'. Use /pipelines tags update or /pipelines tags delete."
                )
            }
        }
    }
}

function Read-GerberPipelinesTagsSubcommand {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Command
    )

    try {
        return Get-GerberMenuSubcommand `
            -CommandName 'pipelines tags' `
            -Command $Command `
            -SubcommandTable (Get-GerberPipelinesTagsCommandCatalog) `
            -AutoSelectFirstSuggestionOnSubmit
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) {
            return ''
        }

        throw
    }
}
