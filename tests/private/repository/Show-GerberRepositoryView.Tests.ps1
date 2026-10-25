BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Show-GerberRepositoryView' {
    It 'delegates to the shared registered subcommand menu' {
        Mock Show-GerberRegisteredSubcommandMenu {}

        Show-GerberRepositoryView -Command ([pscustomobject]@{ Arguments = @('create', 'nuget') })

        Should -Invoke Show-GerberRegisteredSubcommandMenu -Times 1 -ParameterFilter {
            $CommandName -eq 'repository' -and
            $AutoSelectFirstSuggestionOnSubmit -and
            $Command.Arguments[0] -eq 'create'
        }
    }
}
