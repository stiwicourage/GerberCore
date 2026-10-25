BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Show-GerberBranchView' {
    It 'opens /branch find when find is selected and loops back to chooser' {
        $script:branchViewCall = 0
        Mock Get-GerberMenuSubcommand { @('find', '')[$script:branchViewCall++] }
        Mock Invoke-GerberBranchFindFlow {}

        Show-GerberBranchView -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Get-GerberMenuSubcommand -Times 2 -ParameterFilter {
            $CommandName -eq 'branch' -and $AutoSelectFirstSuggestionOnSubmit
        }
        Should -Invoke Invoke-GerberBranchFindFlow -Times 1
    }

    It 'returns immediately when no subcommand is selected' {
        Mock Get-GerberMenuSubcommand { '' }
        Mock Invoke-GerberBranchFindFlow {}

        Show-GerberBranchView -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Invoke-GerberBranchFindFlow -Times 0
    }

    It 'accepts the find subcommand from pre-populated Command arguments' {
        $script:branchArgsCall = 0
        Mock Get-GerberMenuSubcommand { @('find', '')[$script:branchArgsCall++] }
        Mock Invoke-GerberBranchFindFlow {}

        Show-GerberBranchView -Command ([pscustomobject]@{ Arguments = @('find') })

        Should -Invoke Get-GerberMenuSubcommand -Times 1 -ParameterFilter {
            ($Command.Arguments -join ',') -eq 'find'
        }
        Should -Invoke Get-GerberMenuSubcommand -Times 1 -ParameterFilter {
            $Command.Arguments.Count -eq 0
        }
    }

    It 'treats Escape from the branch subcommand prompt as back navigation' {
        Mock Get-GerberMenuSubcommand { throw (Get-GerberMenuEscapeException) }

        $result = Read-GerberBranchSubcommand -Command ([pscustomobject]@{ Arguments = @() })

        $result | Should -Be ''
    }

    It 'rejects an unknown branch subcommand' {
        Mock Get-GerberMenuSubcommand { 'oops' }

        { Show-GerberBranchView -Command ([pscustomobject]@{ Arguments = @() }) } |
            Should -Throw "Unknown branch subcommand 'oops'. Use /branch find, /branch set-searchable, or /branch set-default."
    }

    It 'opens /branch set-default when set-default is selected and loops back to chooser' {
        $script:setDefaultCall = 0
        Mock Get-GerberMenuSubcommand { @('set-default', '')[$script:setDefaultCall++] }
        Mock Invoke-GerberBranchSetDefaultFlow {}

        Show-GerberBranchView -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Invoke-GerberBranchSetDefaultFlow -Times 1
        Should -Invoke Get-GerberMenuSubcommand -Times 2
    }

    It 'opens /branch set-searchable when set-searchable is selected and loops back to chooser' {
        $script:setSearchableCall = 0
        Mock Get-GerberMenuSubcommand { @('set-searchable', '')[$script:setSearchableCall++] }
        Mock Invoke-GerberBranchSetSearchableFlow {}

        Show-GerberBranchView -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Invoke-GerberBranchSetSearchableFlow -Times 1
        Should -Invoke Get-GerberMenuSubcommand -Times 2
    }

    It 'rethrows non-escape exceptions from the subcommand prompt' {
        Mock Get-GerberMenuSubcommand { throw [System.InvalidOperationException]::new('fatal') }

        { Read-GerberBranchSubcommand -Command ([pscustomobject]@{ Arguments = @() }) } |
            Should -Throw -ExceptionType ([System.InvalidOperationException])
    }
}
