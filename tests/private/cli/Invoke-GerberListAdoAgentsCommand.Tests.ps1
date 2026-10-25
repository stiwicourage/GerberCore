BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Invoke-GerberListAdoAgentsCommand' {
    It 'shows the report and waits for continue on success' {
        Mock Show-GerberAdoAgentReport {}
        Mock Wait-GerberContinue {}

        Invoke-GerberListAdoAgentsCommand

        Should -Invoke Show-GerberAdoAgentReport -Times 1
        Should -Invoke Wait-GerberContinue -Times 1
    }

    It 'shows a Gerber-owned error when the report fails recoverably' {
        Mock Show-GerberAdoAgentReport { throw [System.ArgumentException]::new('Gerber could not read Azure DevOps automation pools.') }
        Mock Show-GerberTextBlock {}
        Mock Wait-GerberContinue {}

        Invoke-GerberListAdoAgentsCommand

        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter {
            $Title -eq 'Error' -and
            $Text -eq 'Gerber could not read Azure DevOps automation pools.'
        }
        Should -Invoke Wait-GerberContinue -Times 1
    }

    It 'swallows Escape when the report or continue screen is cancelled' {
        Mock Show-GerberAdoAgentReport { throw (Get-GerberMenuEscapeException) }
        Mock Show-GerberTextBlock {}
        Mock Wait-GerberContinue { throw (Get-GerberMenuEscapeException) }

        { Invoke-GerberListAdoAgentsCommand } | Should -Not -Throw
    }
}
