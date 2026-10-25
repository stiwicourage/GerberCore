BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Show-GerberPipelinesView' {
    It 'opens the registered pipelines submenu with the shared prompt behavior' {
        Mock Show-GerberRegisteredSubcommandMenu {}

        Show-GerberPipelinesView -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Show-GerberRegisteredSubcommandMenu -Times 1 -ParameterFilter {
            $CommandName -eq 'pipelines' -and
            $AutoSelectFirstSuggestionOnSubmit.IsPresent -and
            @($Command.Arguments).Count -eq 0
        }
    }
}
