BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot

    function Get-TestGerberMutableAdoConfiguration {
        return @{
            schemaVersion = 1
            preferences = @{
                theme = 'dark'
            }
            ado = @{
                defaultProfile = 'example'
                profiles = [ordered]@{
                    example = @{
                        projectUrl = 'https://dev.azure.com/example-org/SampleProject'
                        note = 'keep-me'
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
}

Describe 'Set-GerberAdoConnectionProfile' {
    BeforeEach {
        $script:savedConfiguration = $null
        $script:configuration = Get-TestGerberMutableAdoConfiguration
        Mock Get-GerberUserConfiguration { $script:configuration }
        Mock Save-GerberUserConfiguration { $script:savedConfiguration = $Configuration }
        Mock Resolve-GerberUserConfigPath { '/tmp/gerber/config.json' }
    }

    It 'creates a new profile while preserving unrelated configuration' {
        $result = Set-GerberAdoConnectionProfile `
            -Name 'example-server' `
            -ProjectUrl 'https://ado.example.com/azuredevops/DefaultCollection/MyProject' `
            -DeploymentType 'Server' `
            -ServerUrl 'https://ado.example.com/azuredevops'

        $result.Name | Should -Be 'example-server'
        $script:savedConfiguration.preferences.theme | Should -Be 'dark'
        $script:savedConfiguration.ado.profiles['example-server'].projectUrl |
            Should -Be 'https://ado.example.com/azuredevops/DefaultCollection/MyProject'
        $script:savedConfiguration.ado.profiles['example-server'].deploymentType | Should -Be 'Server'
    }

    It 'updates an existing profile case-insensitively and preserves unknown metadata' {
        $result = Set-GerberAdoConnectionProfile `
            -Name 'EXAMPLE' `
            -ProjectUrl 'https://dev.azure.com/example-org/Encoded%20Project'

        $result.Name | Should -Be 'example'
        $script:savedConfiguration.ado.profiles.example.projectUrl |
            Should -Be 'https://dev.azure.com/example-org/Encoded%20Project'
        $script:savedConfiguration.ado.profiles.example.note | Should -Be 'keep-me'
        $script:savedConfiguration.ado.profiles.example.Contains('deploymentType') | Should -BeFalse
        $script:savedConfiguration.ado.profiles.example.Contains('serverUrl') | Should -BeFalse
    }

    It 'rejects invalid writes without saving the configuration' -ForEach @(
        @{
            Action = {
                Set-GerberAdoConnectionProfile -Name 'bad' -ProjectUrl 'relative/path'
            }
            ErrorMessage = '*Provide a full Azure DevOps project URL*'
        }
        @{
            Action = {
                Set-GerberAdoConnectionProfile -Name ' example' -ProjectUrl 'https://dev.azure.com/example-org/SampleProject'
            }
            ErrorMessage = '*leading or trailing whitespace*'
        }
        @{
            Action = {
                $script:configuration.ado.profiles.example.pat = 'secret'
                Set-GerberAdoConnectionProfile -Name 'example' -ProjectUrl 'https://dev.azure.com/example-org/SampleProject'
            }
            ErrorMessage = "*must not contain credential field 'pat'*"
        }
    ) {
        { & $Action } | Should -Throw $ErrorMessage
        Should -Invoke Save-GerberUserConfiguration -Times 0
    }
}
