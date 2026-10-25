BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
    $script:adoPropertiesData = @{
        ado = @{
            defaultApiVersion          = '7.0'
            poolApiVersion             = '7.1'
            policyEvaluationApiVersion = '7.1-preview.1'
        }
    }
}

Describe 'Get-GerberAdoConfiguration' {
    BeforeEach {
        Mock Get-GerberPropertiesData { $script:adoPropertiesData }
        Mock Get-GerberPropertiesPath { '/repo/src/resources/Properties.json' }
        Mock Resolve-GerberAdoConnectionReadiness {
            [pscustomobject]@{
                ConnectionProfile = [pscustomobject]@{
                    ProfileName    = 'example'
                    DeploymentType = 'Services'
                    ServerUri      = [uri]'https://devops.example.test'
                    Organization   = 'ExampleCollection'
                    Collection     = $null
                    Project        = 'ExampleProject'
                    ProjectUri     = [uri]'https://devops.example.test/ExampleCollection/ExampleProject'
                }
            }
        }
        Mock Get-GerberAdoCredentialIdentifier { 'gerber:ado:example:pat' }
    }

    It 'returns the configured Azure DevOps settings from the shared properties data and the resolved user profile' {
        $result = Get-GerberAdoConfiguration

        $result.ProfileName | Should -Be 'example'
        $result.DeploymentType | Should -Be 'Services'
        $result.ServerUrl.AbsoluteUri | Should -Be 'https://devops.example.test/'
        $result.CollectionName | Should -Be 'ExampleCollection'
        $result.ProjectName | Should -Be 'ExampleProject'
        $result.DefaultApiVersion | Should -Be '7.0'
        $result.PoolApiVersion | Should -Be '7.1'
        $result.PolicyEvaluationApiVersion | Should -Be '7.1-preview.1'
        $result.CredentialIdentifier | Should -Be 'gerber:ado:example:pat'
        $result.CollectionUri.AbsoluteUri | Should -Be 'https://devops.example.test/ExampleCollection/'
    }

    It 'builds configuration directly from a supplied connection profile without rerunning readiness selection' {
        Mock Get-GerberAdoCredentialIdentifier { 'gerber:ado:atlas:pat' }
        $connectionProfile = [pscustomobject]@{
            ProfileName    = 'atlas'
            DeploymentType = 'Server'
            ServerUri      = [uri]'https://tfs.example.test/tfs/'
            Organization   = ''
            Collection     = 'DefaultCollection'
            Project        = 'ExampleProject'
            ProjectUri     = [uri]'https://tfs.example.test/tfs/DefaultCollection/ExampleProject'
        }

        $result = Get-GerberAdoConfiguration -ConnectionProfile $connectionProfile

        $result.ProfileName | Should -Be 'atlas'
        $result.DeploymentType | Should -Be 'Server'
        $result.ServerUri.AbsoluteUri | Should -Be 'https://tfs.example.test/tfs/'
        $result.CollectionName | Should -Be 'DefaultCollection'
        $result.CollectionUri.AbsoluteUri | Should -Be 'https://tfs.example.test/tfs/DefaultCollection/'
        $result.ProjectName | Should -Be 'ExampleProject'
        $result.CredentialIdentifier | Should -Be 'gerber:ado:atlas:pat'
        Should -Invoke Resolve-GerberAdoConnectionReadiness -Times 0
    }

    It 'rejects incomplete Azure DevOps settings' {
        Mock Get-GerberPropertiesData {
            @{
                ado = @{
                    defaultApiVersion = '7.0'
                }
            }
        }

        { Get-GerberAdoConfiguration } | Should -Throw "*Missing 'poolApiVersion'*"
    }

    It 'rejects a missing Azure DevOps settings section' {
        Mock Get-GerberPropertiesData { @{ token = @{} } }

        { Get-GerberAdoConfiguration } | Should -Throw "*could not find Azure DevOps defaults*"
    }

    It 'rejects ado settings that are not a hashtable' {
        Mock Get-GerberPropertiesData { @{ ado = 'string-not-hashtable' } }

        { Get-GerberAdoConfiguration } | Should -Throw "*could not find Azure DevOps defaults*"
    }
}
