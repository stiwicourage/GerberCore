BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Show-GerberRegisteredSubcommandMenu' {
    It 'dispatches the selected registered nested command and reopens the parent chooser' {
        Mock Get-GerberMenuSubcommand { @('base-64', '')[$script:subcommandCallCount++] }
        Mock Invoke-GerberRegisteredCommand {}
        $script:subcommandCallCount = 0

        Show-GerberRegisteredSubcommandMenu -CommandName 'tools' -Command ([pscustomobject]@{ Arguments = @('base-64', 'encode') }) -AutoSelectFirstSuggestionOnSubmit

        Should -Invoke Get-GerberMenuSubcommand -Times 1 -ParameterFilter {
            $CommandName -eq 'tools' -and
            ($Command.Arguments -join ',') -eq 'base-64,encode' -and
            $AutoSelectFirstSuggestionOnSubmit
        }
        Should -Invoke Get-GerberMenuSubcommand -Times 1 -ParameterFilter {
            $CommandName -eq 'tools' -and
            $Command.Arguments.Count -eq 0
        }
        Should -Invoke Invoke-GerberRegisteredCommand -Times 1 -ParameterFilter {
            $CommandDefinition.Name -eq 'tools base-64' -and
            ($Command.Arguments -join ',') -eq 'encode'
        }
    }

    It 'returns without dispatching when no subcommand is selected' {
        Mock Get-GerberMenuSubcommand { '' }
        Mock Invoke-GerberRegisteredCommand {}

        Show-GerberRegisteredSubcommandMenu -CommandName 'tools' -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Invoke-GerberRegisteredCommand -Times 0
    }

    It 'treats Escape at the parent submenu prompt as back navigation' {
        Mock Get-GerberMenuSubcommand { throw (Get-GerberMenuEscapeException) }
        Mock Invoke-GerberRegisteredCommand {}

        Show-GerberRegisteredSubcommandMenu -CommandName 'tools' -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Invoke-GerberRegisteredCommand -Times 0
    }

    It 'goes back to the parent chooser when the nested command raises Escape' {
        Mock Get-GerberMenuSubcommand { @('base-64', '')[$script:escapeCallCount++] }
        Mock Invoke-GerberRegisteredCommand { throw (Get-GerberMenuEscapeException) }
        $script:escapeCallCount = 0

        Show-GerberRegisteredSubcommandMenu -CommandName 'tools' -Command ([pscustomobject]@{ Arguments = @('base-64') })

        Should -Invoke Get-GerberMenuSubcommand -Times 2 -ParameterFilter { $CommandName -eq 'tools' }
    }

    It 'fails clearly when the selected submenu action is not registered' {
        Mock Get-GerberMenuSubcommand { 'missing' }

        {
            Show-GerberRegisteredSubcommandMenu -CommandName 'tools' -Command ([pscustomobject]@{ Arguments = @() })
        } | Should -Throw "Unknown subcommand 'missing' for '/tools'."
    }
}
