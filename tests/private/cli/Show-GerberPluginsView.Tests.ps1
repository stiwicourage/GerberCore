BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Show-GerberPluginsView' {
    It 'opens the shared plugins submenu without rendering an overview screen' {
        Mock Show-GerberRegisteredSubcommandMenu {}
        Mock Get-GerberPluginInventory {}
        Mock Show-GerberTextBlock {}

        Show-GerberPluginsView -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Show-GerberRegisteredSubcommandMenu -Times 1 -ParameterFilter {
            $CommandName -eq 'plugins' -and
            ($Command.Arguments | Measure-Object).Count -eq 0 -and
            $AutoSelectFirstSuggestionOnSubmit
        }
        Should -Invoke Get-GerberPluginInventory -Times 0
        Should -Invoke Show-GerberTextBlock -Times 0
    }

    It 'routes direct /plugins info requests through the shared submenu helper' {
        Mock Get-GerberPluginInventory {}
        Mock Show-GerberRegisteredSubcommandMenu {}

        Show-GerberPluginsView -Command ([pscustomobject]@{ Arguments = @('info', 'Gerber.TestPlugin') })

        Should -Invoke Show-GerberRegisteredSubcommandMenu -Times 1 -ParameterFilter {
            $CommandName -eq 'plugins' -and
            ($Command.Arguments -join ',') -eq 'info,Gerber.TestPlugin' -and
            $AutoSelectFirstSuggestionOnSubmit
        }
    }

    It 'routes direct /plugins list requests through the shared submenu helper' {
        Mock Get-GerberPluginInventory {}
        Mock Show-GerberRegisteredSubcommandMenu {}

        Show-GerberPluginsView -Command ([pscustomobject]@{ Arguments = @('list') })

        Should -Invoke Show-GerberRegisteredSubcommandMenu -Times 1 -ParameterFilter {
            $CommandName -eq 'plugins' -and
            ($Command.Arguments -join ',') -eq 'list' -and
            $AutoSelectFirstSuggestionOnSubmit
        }
    }

    It 'still delegates unknown plugin subcommands to the shared submenu flow' {
        Mock Get-GerberPluginInventory {}
        Mock Show-GerberRegisteredSubcommandMenu {}

        Show-GerberPluginsView -Command ([pscustomobject]@{ Arguments = @('unknown') })

        Should -Invoke Show-GerberRegisteredSubcommandMenu -Times 1 -ParameterFilter {
            $CommandName -eq 'plugins' -and
            ($Command.Arguments -join ',') -eq 'unknown' -and
            $AutoSelectFirstSuggestionOnSubmit
        }
    }
}
