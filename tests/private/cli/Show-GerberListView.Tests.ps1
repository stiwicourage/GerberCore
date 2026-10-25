BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Show-GerberListView' {
    It 'delegates the /list submenu to the shared registered-subcommand flow' {
        Mock Show-GerberRegisteredSubcommandMenu {}

        Show-GerberListView -Command ([pscustomobject]@{ Arguments = @('ado-agents') })

        Should -Invoke Show-GerberRegisteredSubcommandMenu -Times 1 -ParameterFilter {
            $CommandName -eq 'list' -and
            ($Command.Arguments -join ',') -eq 'ado-agents' -and
            $AutoSelectFirstSuggestionOnSubmit
        }
    }
}
