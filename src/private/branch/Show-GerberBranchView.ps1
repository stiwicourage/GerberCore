function Show-GerberBranchView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Command
    )

    $currentCommand = $Command
    while ($true) {
        $subcommand = Read-GerberBranchSubcommand -Command $currentCommand
        switch ($subcommand) {
            '' { return }
            'find' {
                Invoke-GerberBranchFindFlow
                $currentCommand = [pscustomobject]@{ Arguments = @() }
                continue
            }
            'set-searchable' {
                Invoke-GerberBranchSetSearchableFlow
                $currentCommand = [pscustomobject]@{ Arguments = @() }
                continue
            }
            'set-default' {
                Invoke-GerberBranchSetDefaultFlow
                $currentCommand = [pscustomobject]@{ Arguments = @() }
                continue
            }
            default {
                throw [System.ArgumentException]::new("Unknown branch subcommand '$subcommand'. Use /branch find, /branch set-searchable, or /branch set-default.")
            }
        }
    }
}

function Read-GerberBranchSubcommand {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Command
    )

    try {
        return Get-GerberMenuSubcommand -CommandName 'branch' -Command $Command -AutoSelectFirstSuggestionOnSubmit
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) {
            return ''
        }
        throw
    }
}
