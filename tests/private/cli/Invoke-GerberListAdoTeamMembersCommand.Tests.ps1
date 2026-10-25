BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Invoke-GerberListAdoTeamMembersCommand' {
    It 'shows the team-members report' {
        Mock Show-GerberAdoTeamMemberReport {}

        Invoke-GerberListAdoTeamMembersCommand

        Should -Invoke Show-GerberAdoTeamMemberReport -Times 1
    }

    It 'shows a Gerber-owned error when the report fails recoverably' {
        Mock Show-GerberAdoTeamMemberReport { throw [System.ArgumentException]::new('Gerber could not read Azure DevOps projects.') }
        Mock Show-GerberTextBlock {}
        Mock Wait-GerberContinue {}

        Invoke-GerberListAdoTeamMembersCommand

        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter {
            $Title -eq 'Error' -and
            $Text -eq 'Gerber could not read Azure DevOps projects.'
        }
        Should -Invoke Wait-GerberContinue -Times 1
    }

    It 'swallows Escape when the report or continue screen is cancelled' {
        Mock Show-GerberAdoTeamMemberReport { throw (Get-GerberMenuEscapeException) }
        Mock Show-GerberTextBlock {}
        Mock Wait-GerberContinue { throw (Get-GerberMenuEscapeException) }

        { Invoke-GerberListAdoTeamMembersCommand } | Should -Not -Throw
    }
}
