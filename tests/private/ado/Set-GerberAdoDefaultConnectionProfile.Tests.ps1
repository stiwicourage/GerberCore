BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Set-GerberAdoDefaultConnectionProfile' {
    BeforeEach {
        $script:savedConfiguration = $null
        Mock Get-GerberUserConfiguration {
            @{
                schemaVersion = 1
                preferences = @{
                    theme = 'dark'
                }
                ado = @{
                    profiles = [ordered]@{
                        example = @{
                            projectUrl = 'https://dev.azure.com/example-org/SampleProject'
                        }
                        Internal = @{
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

    It 'sets the default profile using the stored profile name casing' {
        $result = Set-GerberAdoDefaultConnectionProfile -Name 'internal'

        $result.Name | Should -Be 'Internal'
        $script:savedConfiguration.preferences.theme | Should -Be 'dark'
        $script:savedConfiguration.ado.defaultProfile | Should -Be 'Internal'
    }

    It 'rejects a default profile that does not exist' {
        { Set-GerberAdoDefaultConnectionProfile -Name 'missing' } | Should -Throw "*profile 'missing' was not found*"
        Should -Invoke Save-GerberUserConfiguration -Times 0
    }
}
