BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot

    function Get-TestGerberResolvedProfileConfiguration {
        return @{
            schemaVersion = 1
            ado = @{
                defaultProfile = 'example'
                profiles = [ordered]@{
                    example = @{
                        projectUrl = 'https://dev.azure.com/example-org/SampleProject'
                    }
                    legacy = @{
                        projectUrl = 'https://myorganization.visualstudio.com/DefaultCollection/MyProject'
                    }
                    internal = @{
                        projectUrl = 'https://ado.example.com/azuredevops/DefaultCollection/My%20Project'
                        deploymentType = 'Server'
                        serverUrl = 'https://ado.example.com/azuredevops'
                    }
                    standard = @{
                        projectUrl = 'https://ado.example.com/tfs/DefaultCollection/MyProject'
                    }
                }
            }
        }
    }
}

Describe 'Resolve-GerberAdoConnectionProfile' {
    BeforeEach {
        Mock Get-GerberUserConfiguration { Get-TestGerberResolvedProfileConfiguration }
        Mock Resolve-GerberUserConfigPath { '/tmp/gerber/config.json' }
    }

    It 'resolves an explicit profile selection' {
        $result = Resolve-GerberAdoConnectionProfile -Name 'EXAMPLE'

        $result.ProfileName | Should -Be 'example'
        $result.DeploymentType | Should -Be 'Services'
        $result.Organization | Should -Be 'example-org'
        $result.Project | Should -Be 'SampleProject'
        $result.ProjectUri.AbsoluteUri | Should -Be 'https://dev.azure.com/example-org/SampleProject'
    }

    It 'resolves the default profile when no name is supplied' {
        $result = Resolve-GerberAdoConnectionProfile

        $result.ProfileName | Should -Be 'example'
        $result.Project | Should -Be 'SampleProject'
    }

    It 'rejects a missing explicit profile' {
        { Resolve-GerberAdoConnectionProfile -Name 'missing' } |
            Should -Throw "*profile 'missing' was not found*"
    }

    It 'rejects a missing default profile selection' {
        Mock Get-GerberUserConfiguration {
            @{
                schemaVersion = 1
                ado = @{
                    profiles = @{
                        example = @{
                            projectUrl = 'https://dev.azure.com/example-org/SampleProject'
                        }
                    }
                }
            }
        }

        { Resolve-GerberAdoConnectionProfile } | Should -Throw "*does not define 'ado.defaultProfile'*"
    }

    It 'parses services, legacy services, and server profile URLs' -ForEach @(
        @{
            Name = 'legacy'
            DeploymentType = 'Services'
            Organization = 'myorganization'
            Collection = $null
            Project = 'MyProject'
            ServerUri = 'https://myorganization.visualstudio.com'
            ProjectUri = 'https://myorganization.visualstudio.com/DefaultCollection/MyProject'
        }
        @{
            Name = 'standard'
            DeploymentType = 'Server'
            Organization = $null
            Collection = 'DefaultCollection'
            Project = 'MyProject'
            ServerUri = 'https://ado.example.com/tfs'
            ProjectUri = 'https://ado.example.com/tfs/DefaultCollection/MyProject'
        }
        @{
            Name = 'internal'
            DeploymentType = 'Server'
            Organization = $null
            Collection = 'DefaultCollection'
            Project = 'My Project'
            ServerUri = 'https://ado.example.com/azuredevops'
            ProjectUri = 'https://ado.example.com/azuredevops/DefaultCollection/My%20Project'
        }
    ) {
        $result = Resolve-GerberAdoConnectionProfile -Name $Name

        $result.DeploymentType | Should -Be $DeploymentType
        $result.Organization | Should -Be $Organization
        $result.Collection | Should -Be $Collection
        $result.Project | Should -Be $Project
        $result.ServerUri.AbsoluteUri.TrimEnd('/') | Should -Be $ServerUri
        $result.ProjectUri.AbsoluteUri.TrimEnd('/') | Should -Be $ProjectUri
    }

    It 'does not perform network, prompting, or startup side effects during profile resolution' {
        Mock Invoke-RestMethod { throw 'Invoke-RestMethod should not be called.' }
        Mock Invoke-WebRequest { throw 'Invoke-WebRequest should not be called.' }
        Mock Get-Credential { throw 'Get-Credential should not be called.' }
        Mock Save-GerberUserConfiguration { throw 'Save-GerberUserConfiguration should not be called.' }

        $result = Resolve-GerberAdoConnectionProfile -Name 'internal'

        $result.Project | Should -Be 'My Project'
        Should -Invoke Invoke-RestMethod -Times 0
        Should -Invoke Invoke-WebRequest -Times 0
        Should -Invoke Get-Credential -Times 0
        Should -Invoke Save-GerberUserConfiguration -Times 0
    }
}
