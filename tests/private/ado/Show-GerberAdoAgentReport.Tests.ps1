BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Show-GerberAdoAgentReport' {
    It 'renders script-style BUILD before DEPLOY and shows empty states' {
        Mock Get-GerberAdoAgentReport {
            [pscustomobject]@{
                Configuration = [pscustomobject]@{
                    CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                    ProjectName = 'ExampleProject'
                }
                Sections = @(
                    [pscustomobject]@{
                        Name = 'BUILD'
                        PoolType = 'automation'
                        PoolList = @(
                            [pscustomobject]@{
                                Name = 'Alpha Pool'
                                AgentList = @()
                            }
                            [pscustomobject]@{
                                Name = 'Build Pool'
                                AgentList = @(
                                    [pscustomobject]@{
                                        Name = 'build-agent-01'
                                        Version = '3.225.0'
                                        Status = 'online'
                                    }
                                )
                            }
                        )
                    }
                    [pscustomobject]@{
                        Name = 'DEPLOY'
                        PoolType = 'deployment'
                        PoolList = @()
                    }
                )
                VersionList = @('3.225.0')
            }
        }
        Mock Clear-Host {}
        Mock Write-GerberScreenLine {}
        Mock Write-GerberAdoColorLine {}
        Mock Write-GerberAdoStyledText {}
        Mock Get-GerberPromptColorPair {
            [pscustomobject]@{
                BackgroundColor = [System.ConsoleColor]::Black
            }
        }

        Show-GerberAdoAgentReport

        Should -Invoke Write-GerberAdoColorLine -Times 1 -ParameterFilter { $Text -eq '=== BUILD AGENTS (automation pools) ===' }
        Should -Invoke Write-GerberAdoColorLine -Times 1 -ParameterFilter { $Text -eq '=== DEPLOY AGENTS (deployment pools) ===' }
        Should -Invoke Write-GerberAdoColorLine -Times 2 -ParameterFilter { $Text -eq 'Agent Name                         Version       Status    Pool' }
        Should -Invoke Write-GerberAdoColorLine -Times 1 -ParameterFilter { $Text -eq 'Pool: Alpha Pool' }
        Should -Invoke Write-GerberAdoColorLine -Times 1 -ParameterFilter { $Text -eq '  (No agents in this pool)' }
        Should -Invoke Write-GerberAdoColorLine -Times 1 -ParameterFilter { $Text -eq 'No pools found for poolType=deployment' }
        Should -Invoke Write-GerberAdoStyledText -Times 1 -ParameterFilter { $Text -eq 'build-agent-01                     ' }
        Should -Invoke Write-GerberAdoStyledText -Times 1 -ParameterFilter { $Text -eq '3.225.0       ' }
        Should -Invoke Write-GerberAdoStyledText -Times 1 -ParameterFilter { $Text -eq 'Online    ' }
        Should -Invoke Write-GerberAdoStyledText -Times 2 -ParameterFilter { $Text -eq '3.225.0       ' }
    }

    It 'assigns one style per unique version' {
        Mock Get-GerberPromptColorPair {
            [pscustomobject]@{
                BackgroundColor = [System.ConsoleColor]::Black
            }
        }

        $result = Get-GerberAdoVersionStyleTable -VersionList @('1.0.0', '2.0.0', '3.0.0')

        $result.Keys.Count | Should -Be 3
        $result['1.0.0'].ForegroundColor | Should -Not -Be $result['2.0.0'].ForegroundColor
        $result['1.0.0'].BackgroundColor | Should -Be ([System.ConsoleColor]::Black)
    }

    It 'shows explicit legend and color fallbacks when no versions are available' {
        Mock Write-GerberAdoColorLine {}

        Write-GerberAdoVersionLegend -VersionList @() -StyleTable @{}

        Should -Invoke Write-GerberAdoColorLine -Times 1 -ParameterFilter { $Text -eq '=== Version colors ===' }
        Should -Invoke Write-GerberAdoColorLine -Times 1 -ParameterFilter { $Text -eq 'No version data was found.' }
        (Get-GerberAdoVersionColorList -BackgroundColor ([System.ConsoleColor]::Cyan)).Count | Should -BeGreaterThan 0
    }

    It 'writes styled text through the shared prompt styling helper' {
        Mock Write-GerberStyledPromptText {}

        Write-GerberAdoStyledText -Text '1.0.0         ' -Style ([pscustomobject]@{
                ForegroundColor = [System.ConsoleColor]::Green
                BackgroundColor = [System.ConsoleColor]::Black
            })

        Should -Invoke Write-GerberStyledPromptText -Times 1 -ParameterFilter { $Text -eq '1.0.0         ' }
    }

    It 'maps agent status to the script-style online and offline labels' {
        (Get-GerberAdoStatusDisplayText -Status 'online') | Should -Be 'Online'
        (Get-GerberAdoStatusDisplayText -Status 'offline') | Should -Be 'Offline'
        (Get-GerberAdoStatusDisplayText -Status 'busy') | Should -Be 'Offline'
    }

    It 'writes colored line with styled text and newline' {
        Mock Get-GerberPromptColorPair {
            [pscustomobject]@{
                BackgroundColor = [System.ConsoleColor]::Black
            }
        }
        Mock Write-GerberAdoStyledText {}
        Mock -CommandName 'Write-Host' -MockWith {}

        Write-GerberAdoColorLine -Text 'Test line' -ForegroundColor ([System.ConsoleColor]::Cyan)

        Should -Invoke Write-GerberAdoStyledText -Times 1
        Should -Invoke Get-GerberPromptColorPair -Times 1
    }

    It '<Name>' -TestCases @(
        @{ Name = 'returns green style for Online status'; Status = 'Online'; Color = [System.ConsoleColor]::Green }
        @{ Name = 'returns red style for Offline status'; Status = 'Offline'; Color = [System.ConsoleColor]::Red }
    ) {
        param($Status, $Color)

        Mock Get-GerberPromptColorPair {
            [pscustomobject]@{
                BackgroundColor = [System.ConsoleColor]::Black
            }
        }

        $style = Get-GerberAdoStatusStyle -Status $Status

        $style.ForegroundColor | Should -Be $Color
        $style.BackgroundColor | Should -Be ([System.ConsoleColor]::Black)
    }

    It 'returns empty string for null or unknown version' {
        (Get-GerberAdoVersionDisplayText -Version $null) | Should -Be ''
        (Get-GerberAdoVersionDisplayText -Version '') | Should -Be ''
        (Get-GerberAdoVersionDisplayText -Version 'unknown') | Should -Be ''
    }

    It 'returns version as-is for known version' {
        (Get-GerberAdoVersionDisplayText -Version '3.225.0') | Should -Be '3.225.0'
    }

    It 'pads null text as empty string' {
        $result = Get-GerberAdoPaddedText -Text $null -Width 10

        $result | Should -Be '          '
        $result.Length | Should -Be 10
    }

    It 'returns cyan fallback when no colors available' {
        $result = Get-GerberAdoVersionColorList -BackgroundColor ([System.ConsoleColor]::Black)

        $result.Count | Should -BeGreaterThan 0
        $result[0] | Should -Be ([System.ConsoleColor]::Cyan)
    }

    It 'filters the background color out of the version palette' {
        $result = Get-GerberAdoVersionColorList -BackgroundColor ([System.ConsoleColor]::Cyan)

        $result | Should -Not -Contain ([System.ConsoleColor]::Cyan)
        $result.Count | Should -BeGreaterThan 0
    }
}
