BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Remove-GerberAdoConnectionProfile' {
    BeforeEach {
        $script:savedConfiguration = $null
        Mock Get-GerberUserConfiguration {
            @{
                schemaVersion = 1
                preferences = @{
                    theme = 'dark'
                }
                ado = @{
                    defaultProfile = 'example'
                    profiles = [ordered]@{
                        example = @{
                            projectUrl = 'https://dev.azure.com/example-org/SampleProject'
                        }
                        internal = @{
                            projectUrl = 'https://ado.example.com/tfs/DefaultCollection/MyProject'
                            deploymentType = 'Server'
                            serverUrl = 'https://ado.example.com/tfs'
                        }
                    }
                }
            }
        }
        Mock Save-GerberUserConfiguration { $script:savedConfiguration = $Configuration }
        Mock Resolve-GerberUserConfigPath { '/tmp/gerber/config.json' }
    }

    It 'removes the selected profile and preserves unrelated configuration' {
        Remove-GerberAdoConnectionProfile -Name 'internal'

        $script:savedConfiguration.preferences.theme | Should -Be 'dark'
        $script:savedConfiguration.ado.profiles.Contains('internal') | Should -BeFalse
        $script:savedConfiguration.ado.profiles.Contains('example') | Should -BeTrue
        $script:savedConfiguration.ado.defaultProfile | Should -Be 'example'
    }

    It 'clears the default profile when removing it' {
        Remove-GerberAdoConnectionProfile -Name 'example'

        $script:savedConfiguration.ado.Contains('defaultProfile') | Should -BeFalse
    }

    It 'rejects removing an unknown profile' {
        { Remove-GerberAdoConnectionProfile -Name 'missing' } | Should -Throw "*profile 'missing' was not found*"
        Should -Invoke Save-GerberUserConfiguration -Times 0
    }
}
