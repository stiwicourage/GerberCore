BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot

    function Initialize-TestGerberAdoMemberListScreenMock {
        Mock Clear-Host {}
        Mock Write-GerberScreenLine {}
        Mock Get-GerberPromptColorPair { [pscustomobject]@{ BackgroundColor = [System.ConsoleColor]::Black } }
        Mock ConvertTo-GerberPromptLineStyle { [pscustomobject]@{} }
        Mock Write-GerberAdoStyledText {}
    }

    function Get-TestGerberAdoMemberListContext {
        param(
            [Parameter(Mandatory)]
            [pscustomobject]$Team
        )

        return [pscustomobject]@{
            Project = [pscustomobject]@{ Id = 'p1'; Name = 'MyProject'; TeamList = @() }
            Report  = [pscustomobject]@{ ProjectList = @([pscustomobject]@{ Id = 'p1'; Name = 'MyProject'; TeamList = @() }) }
            Team    = $Team
        }
    }

    function Assert-TestGerberAdoExportSelection {
        param(
            [Parameter(Mandatory)]
            [string]$Selection
        )

        Mock Export-GerberAdoTeamMemberReport {}

        $result = Invoke-GerberAdoTeamMemberExportSelection `
            -Report ([pscustomobject]@{ ProjectList = @() }) `
            -Selection $Selection

        $result | Should -BeTrue
        Should -Invoke Export-GerberAdoTeamMemberReport -Times 1 -ParameterFilter { $Format -eq $Selection }
    }

    function Assert-TestGerberAdoFileExport {
        param(
            [Parameter(Mandatory)]
            [string]$Format,

            [Parameter(Mandatory)]
            [string]$ExpectedPathSuffix,

            [Parameter(Mandatory)]
            [string]$ExpectedMessageFragment
        )

        $script:lastExportPath = ''
        $script:lastExportMessage = ''
        Mock Get-Location { [pscustomobject]@{ Path = '/tmp' } }
        Mock Get-GerberAdoTeamMemberExportBaseName { 'gerber-ado-team-members-20250101-120000' }
        Mock Set-Content { $script:lastExportPath = $Path }
        Mock Write-GerberScreenLine {
            if (-not [string]::IsNullOrWhiteSpace($Text)) {
                $script:lastExportMessage = $Text
            }
        }

        Export-GerberAdoTeamMemberReport -Report ([pscustomobject]@{ ProjectList = @() }) -Format $Format

        Should -Invoke Set-Content -Times 1
        Should -Invoke Write-GerberScreenLine -Times 1
        $script:lastExportPath | Should -BeLike "*$ExpectedPathSuffix"
        $script:lastExportMessage | Should -BeLike "*$ExpectedMessageFragment*"
    }
}

Describe 'Show-GerberAdoTeamMemberReport' {
    It 'shows loading message, fetches report, then clears and renders summary' {
        Mock Get-GerberAdoTeamMemberReport {
            [pscustomobject]@{
                Configuration = [pscustomobject]@{}
                ProjectList = @()
            }
        }
        Mock Start-GerberScreen {}
        Mock Write-GerberScreenLine {}
        Mock Write-GerberAdoColorLine {}
        Mock Read-GerberNumberedMenuPrompt { 'continue' }

        Show-GerberAdoTeamMemberReport

        Should -Invoke Write-GerberScreenLine -ParameterFilter { $Text -eq 'Connecting to Azure DevOps...' }
        Should -Invoke Start-GerberScreen -Times 2 -ParameterFilter { $Name -eq '/list ado-team-members' }
        Should -Invoke Write-GerberAdoColorLine -ParameterFilter { $Text -eq 'No projects found.' }
    }

    It 'shows project and team summary with member counts' {
        $report = [pscustomobject]@{
            Configuration = [pscustomobject]@{}
            ProjectList = @(
                [pscustomobject]@{
                    Id = 'p1'
                    Name = 'Alpha Project'
                    TeamList = @(
                        [pscustomobject]@{
                            Id = 't1'
                            Name = 'Core Team'
                            MemberList = @(
                                [pscustomobject]@{ DisplayName = 'Alice'; UniqueName = 'alice@example.test' }
                                [pscustomobject]@{ DisplayName = 'Bob'; UniqueName = 'bob@example.test' }
                            )
                        }
                    )
                }
            )
        }
        Mock Clear-Host {}
        Mock Write-GerberScreenLine {}
        Mock Write-GerberAdoColorLine {}
        Mock Read-GerberNumberedMenuPrompt { throw (Get-GerberMenuEscapeException) }

        Show-GerberAdoTeamMemberSummary -Report $report

        Should -Invoke Write-GerberAdoColorLine -Times 1 -ParameterFilter { $Text -eq '=== Projects and Teams ===' }
        Should -Invoke Write-GerberAdoColorLine -Times 1 -ParameterFilter { $Text -eq 'Alpha Project' }
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq '  Core Team (2 members)' }
    }

    It 'shows DarkYellow message when project list is empty' {
        Mock Write-GerberAdoColorLine {}
        Mock Write-GerberScreenLine {}

        Show-GerberAdoTeamMemberSummary -Report ([pscustomobject]@{ ProjectList = @() })

        Should -Invoke Write-GerberAdoColorLine -Times 1 -ParameterFilter { $ForegroundColor -eq [System.ConsoleColor]::DarkYellow }
    }

    It 'shows DarkYellow message when team has no members' {
        Initialize-TestGerberAdoMemberListScreenMock
        Mock Read-GerberNumberedMenuPrompt { throw (Get-GerberMenuEscapeException) }

        $context = Get-TestGerberAdoMemberListContext -Team ([pscustomobject]@{ Id = 't1'; Name = 'Empty Team'; MemberList = @() })

        Show-GerberAdoMemberListScreen `
            -Report $context.Report `
            -Project $context.Project `
            -Team $context.Team

        Should -Invoke Write-GerberAdoStyledText -Times 1 -ParameterFilter { $Text -eq '  (No members in this team)' }
    }

    It 'shows members with display name and unique name' {
        Initialize-TestGerberAdoMemberListScreenMock
        Mock Read-GerberNumberedMenuPrompt { throw (Get-GerberMenuEscapeException) }

        $context = Get-TestGerberAdoMemberListContext -Team ([pscustomobject]@{
            Id = 't1'
            Name = 'Dev Team'
            MemberList = @(
                [pscustomobject]@{ DisplayName = 'Alice Smith'; UniqueName = 'alice@example.test' }
            )
        })

        Show-GerberAdoMemberListScreen `
            -Report $context.Report `
            -Project $context.Project `
            -Team $context.Team

        Should -Invoke Write-GerberScreenLine -ParameterFilter { $Text -eq '  Alice Smith (alice@example.test)' }
    }

    It 'drill-in returns immediately when project list is empty' {
        Mock Clear-Host {}
        Mock Write-GerberScreenLine {}
        Mock Read-GerberNumberedMenuPrompt {}

        Show-GerberAdoTeamMemberDrillIn -Report ([pscustomobject]@{ ProjectList = @() })

        Should -Invoke Read-GerberNumberedMenuPrompt -Times 0
    }

    It 'drill-in returns when Escape is pressed at project chooser' {
        Mock Clear-Host {}
        Mock Write-GerberScreenLine {}
        Mock Write-GerberAdoColorLine {}
        Mock Read-GerberNumberedMenuPrompt { throw (Get-GerberMenuEscapeException) }

        $report = [pscustomobject]@{
            ProjectList = @(
                [pscustomobject]@{ Id = 'p1'; Name = 'Alpha'; TeamList = @() }
            )
        }

        Show-GerberAdoTeamMemberDrillIn -Report $report

        Should -Invoke Read-GerberNumberedMenuPrompt -Times 1
    }

    It 'export selection returns true for json and triggers export' {
        Assert-TestGerberAdoExportSelection -Selection 'json'
    }

    It 'export selection returns false for continue selection' {
        $result = Invoke-GerberAdoTeamMemberExportSelection `
            -Report ([pscustomobject]@{ ProjectList = @() }) `
            -Selection 'continue'

        $result | Should -BeFalse
    }

    It 'export prompt propagates Escape to the caller' {
        Mock Read-GerberNumberedMenuPrompt { throw (Get-GerberMenuEscapeException) }

        { Show-GerberAdoTeamMemberExportPrompt -Report ([pscustomobject]@{ ProjectList = @() }) -DrawScreen {} } |
            Should -Throw
    }

    It 'member list screen exits cleanly when Escape is pressed at export' {
        Initialize-TestGerberAdoMemberListScreenMock
        Mock Read-GerberNumberedMenuPrompt { throw (Get-GerberMenuEscapeException) }

        $context = Get-TestGerberAdoMemberListContext -Team ([pscustomobject]@{ Id = 't1'; Name = 'Y'; MemberList = @() })

        { Show-GerberAdoMemberListScreen `
            -Report $context.Report `
            -Project $context.Project `
            -Team $context.Team } | Should -Not -Throw
    }

    It 'export menu items contain all four options' {
        $items = Get-GerberAdoTeamMemberExportMenuItemList

        $items.Count | Should -Be 4
        $items.Value | Should -Contain 'json'
        $items.Value | Should -Contain 'csv'
        $items.Value | Should -Contain 'html'
        $items.Value | Should -Contain 'continue'
        $items[0].Value | Should -Be 'continue'
    }

    It 'project menu items have correct Number, Label, and Value' {
        $projectList = @(
            [pscustomobject]@{ Id = 'p1'; Name = 'Alpha'; TeamList = @() }
            [pscustomobject]@{ Id = 'p2'; Name = 'Beta'; TeamList = @([pscustomobject]@{ MemberList = @() }) }
        )

        $items = Get-GerberAdoProjectMenuItemList -ProjectList $projectList

        $items.Count | Should -Be 2
        $items[0].Number | Should -Be 1
        $items[0].Label | Should -Be 'Alpha'
        $items[0].Value | Should -Be 'p1'
        $items[1].Number | Should -Be 2
    }

    It 'team menu items have correct Number, Label, and Value' {
        $teamList = @(
            [pscustomobject]@{ Id = 't1'; Name = 'Core Team'; MemberList = @() }
        )

        $items = Get-GerberAdoTeamMenuItemList -TeamList $teamList

        $items.Count | Should -Be 1
        $items[0].Number | Should -Be 1
        $items[0].Label | Should -Be 'Core Team'
        $items[0].Value | Should -Be 't1'
    }

    It 'team chooser returns empty string when project has no teams' {
        Mock Clear-Host {}
        Mock Write-GerberScreenLine {}
        Mock Write-GerberAdoColorLine {}

        $result = Read-GerberAdoTeamMenuChoice -Project ([pscustomobject]@{ Name = 'P'; TeamList = @() })

        $result | Should -Be ''
    }

    It 'JSON export writes file to current location with timestamped name' {
        Assert-TestGerberAdoFileExport `
            -Format 'json' `
            -ExpectedPathSuffix 'gerber-ado-team-members-20250101-120000.json' `
            -ExpectedMessageFragment 'Exported JSON'
    }

    It 'CSV export flattens project, team, and member rows' {
        Mock Get-Location { [pscustomobject]@{ Path = 'C:/tmp' } }
        Mock Get-GerberAdoTeamMemberExportBaseName { 'gerber-ado-team-members-20250101-120000' }
        Mock Export-Csv {}
        Mock Write-GerberScreenLine {}

        $report = [pscustomobject]@{
            ProjectList = @(
                [pscustomobject]@{
                    Name = 'Proj'
                    TeamList = @(
                        [pscustomobject]@{
                            Name = 'Team'
                            MemberList = @(
                                [pscustomobject]@{ DisplayName = 'Alice'; UniqueName = 'alice@example.test' }
                            )
                        }
                    )
                }
            )
        }

        $rows = Get-GerberAdoTeamMemberCsvRowList -Report $report

        $rows.Count | Should -Be 1
        $rows[0].Project | Should -Be 'Proj'
        $rows[0].Team | Should -Be 'Team'
        $rows[0].DisplayName | Should -Be 'Alice'
        $rows[0].UniqueName | Should -Be 'alice@example.test'
    }

    It 'HTML export content includes filter input and table headers' {
        $report = [pscustomobject]@{
            ProjectList = @(
                [pscustomobject]@{
                    Name = 'Proj'
                    TeamList = @(
                        [pscustomobject]@{
                            Name = 'Team'
                            MemberList = @(
                                [pscustomobject]@{ DisplayName = 'Alice'; UniqueName = 'alice@example.test' }
                            )
                        }
                    )
                }
            )
        }

        $html = Get-GerberAdoTeamMemberHtmlContent -Report $report

        $html | Should -BeLike '*<input*filter*'
        $html | Should -BeLike '*<th>Project</th>*'
        $html | Should -BeLike '*Alice*'
    }

    It 'HTML rows HTML-encode special characters' {
        $report = [pscustomobject]@{
            ProjectList = @(
                [pscustomobject]@{
                    Name = 'A&B'
                    TeamList = @(
                        [pscustomobject]@{
                            Name = '<Team>'
                            MemberList = @(
                                [pscustomobject]@{ DisplayName = 'Bob'; UniqueName = 'bob@example.test' }
                            )
                        }
                    )
                }
            )
        }

        $rows = Get-GerberAdoTeamMemberHtmlRowList -Report $report

        $rows | Should -BeLike '*A&amp;B*'
        $rows | Should -BeLike '*&lt;Team&gt;*'
    }

    It 'export base name follows gerber-ado-team-members-yyyyMMdd-HHmmss format' {
        $result = Get-GerberAdoTeamMemberExportBaseName

        $result | Should -Match '^gerber-ado-team-members-\d{8}-\d{6}$'
    }

    It 'export selection returns true for csv and triggers csv export' {
        Assert-TestGerberAdoExportSelection -Selection 'csv'
    }

    It 'export selection returns true for html and triggers html export' {
        Assert-TestGerberAdoExportSelection -Selection 'html'
    }

    It 'export prompt loops when export returns true then exits on continue' {
        $script:exportCallCount = 0
        Mock Read-GerberNumberedMenuPrompt {
            if ($script:exportCallCount -eq 0) {
                $script:exportCallCount++
                return 'json'
            }
            return 'continue'
        }
        Mock Export-GerberAdoTeamMemberReport {}

        Show-GerberAdoTeamMemberExportPrompt -Report ([pscustomobject]@{ ProjectList = @() }) -DrawScreen {}

        Should -Invoke Export-GerberAdoTeamMemberReport -Times 1 -ParameterFilter { $Format -eq 'json' }
        Should -Invoke Read-GerberNumberedMenuPrompt -Times 2
    }

    It 'drill-in selects project then shows team chooser and loops back' {
        $script:drillCallCount = 0
        Mock Read-GerberAdoProjectMenuChoice {
            if ($script:drillCallCount -eq 0) {
                $script:drillCallCount++
                return 'p1'
            }
            return ''
        }
        Mock Show-GerberAdoTeamChooser {}

        $report = [pscustomobject]@{
            ProjectList = @(
                [pscustomobject]@{ Id = 'p1'; Name = 'Alpha'; TeamList = @() }
            )
        }

        Show-GerberAdoTeamMemberDrillIn -Report $report

        Should -Invoke Show-GerberAdoTeamChooser -Times 1
        Should -Invoke Read-GerberAdoProjectMenuChoice -Times 2
    }

    It 'team chooser selects team shows member screen then loops back when Esc' {
        $script:teamChooserCount = 0
        Mock Read-GerberAdoTeamMenuChoice {
            if ($script:teamChooserCount -eq 0) {
                $script:teamChooserCount++
                return 't1'
            }
            return ''
        }
        Mock Show-GerberAdoMemberListScreen {}

        $project = [pscustomobject]@{
            Id = 'p1'
            Name = 'Alpha'
            TeamList = @(
                [pscustomobject]@{ Id = 't1'; Name = 'Core Team'; MemberList = @() }
            )
        }

        Show-GerberAdoTeamChooser -Report ([pscustomobject]@{ ProjectList = @() }) -Project $project

        Should -Invoke Show-GerberAdoMemberListScreen -Times 1
        Should -Invoke Read-GerberAdoTeamMenuChoice -Times 2
    }

    It 'team menu choice shows menu when project has teams and returns selected value' {
        Mock Clear-Host {}
        Mock Write-GerberScreenLine {}
        Mock Write-GerberAdoColorLine {}
        Mock Read-GerberNumberedMenuPrompt { 't1' }

        $project = [pscustomobject]@{
            Name = 'MyProject'
            TeamList = @(
                [pscustomobject]@{ Id = 't1'; Name = 'Core Team'; MemberList = @() }
            )
        }

        $result = Read-GerberAdoTeamMenuChoice -Project $project

        $result | Should -Be 't1'
        Should -Invoke Read-GerberNumberedMenuPrompt -Times 1
    }

    It 'team menu choice returns empty on Escape when teams exist' {
        Mock Clear-Host {}
        Mock Write-GerberScreenLine {}
        Mock Write-GerberAdoColorLine {}
        Mock Read-GerberNumberedMenuPrompt { throw (Get-GerberMenuEscapeException) }

        $project = [pscustomobject]@{
            Name = 'MyProject'
            TeamList = @(
                [pscustomobject]@{ Id = 't1'; Name = 'Core Team'; MemberList = @() }
            )
        }

        $result = Read-GerberAdoTeamMenuChoice -Project $project

        $result | Should -Be ''
    }

    It 'CSV export writes to current directory with timestamped name' {
        Mock Get-Location { [pscustomobject]@{ Path = '/tmp' } }
        Mock Get-GerberAdoTeamMemberExportBaseName { 'gerber-ado-team-members-20250101-120000' }
        Mock Export-Csv {}
        Mock Write-GerberScreenLine {}

        $report = [pscustomobject]@{
            ProjectList = @(
                [pscustomobject]@{
                    Name = 'P'
                    TeamList = @(
                        [pscustomobject]@{
                            Name = 'T'
                            MemberList = @([pscustomobject]@{ DisplayName = 'A'; UniqueName = 'a@example.test' })
                        }
                    )
                }
            )
        }

        Export-GerberAdoTeamMemberReport -Report $report -Format 'csv'

        Should -Invoke Export-Csv -Times 1 -ParameterFilter { $Path -like '*gerber-ado-team-members-20250101-120000.csv*' }
        Should -Invoke Write-GerberScreenLine -ParameterFilter { $Text -like '*Exported CSV*' }
    }

    It 'HTML export writes to current directory with timestamped name' {
        Assert-TestGerberAdoFileExport `
            -Format 'html' `
            -ExpectedPathSuffix 'gerber-ado-team-members-20250101-120000.html' `
            -ExpectedMessageFragment 'Exported HTML'
    }
}
