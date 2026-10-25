BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Show-GerberToolsView' {
    It 'delegates the tools submenu to the shared registered-subcommand menu' {
        Mock Show-GerberRegisteredSubcommandMenu {}

        Show-GerberToolsView -Command ([pscustomobject]@{ Arguments = @('base-64', 'encode') })

        Should -Invoke Show-GerberRegisteredSubcommandMenu -Times 1 -ParameterFilter {
            $CommandName -eq 'tools' -and
            ($Command.Arguments -join ',') -eq 'base-64,encode' -and
            $AutoSelectFirstSuggestionOnSubmit
        }
    }
}
