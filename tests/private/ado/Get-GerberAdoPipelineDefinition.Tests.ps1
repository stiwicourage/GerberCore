BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoPipelineDefinition' {
    It 'returns success with YamlPath when lookup succeeds' {
        Mock Get-GerberAdoBranchRequestUri { [uri]'https://example.test/api' }
        Mock Invoke-GerberAdoRestRequest {
            [pscustomobject]@{
                configuration = [pscustomobject]@{ path = '/pipelines/build.yml' }
            }
        }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'TestProj'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
        }
        $result = Get-GerberAdoPipelineDefinition -Context $context -PipelineId 42

        $result.Success | Should -BeTrue
        $result.YamlPath | Should -Be '/pipelines/build.yml'
    }

    It 'returns failure with empty YamlPath when lookup throws' {
        Mock Get-GerberAdoBranchRequestUri { [uri]'https://example.test/api' }
        Mock Invoke-GerberAdoRestRequest { throw [System.InvalidOperationException]::new('API error') }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'TestProj'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
        }
        $result = Get-GerberAdoPipelineDefinition -Context $context -PipelineId 42

        $result.Success | Should -BeFalse
        $result.YamlPath | Should -Be ''
    }

    It 'uses the selected project scope for pipeline-definition lookups when configuration points elsewhere' {
        $script:capturedRelativePath = $null
        Mock Get-GerberAdoBranchRequestUri {
            $script:capturedRelativePath = $RelativePath
            [uri]'https://example.test/api'
        }
        Mock Invoke-GerberAdoRestRequest {
            [pscustomobject]@{
                configuration = [pscustomobject]@{ path = '/pipelines/build.yml' }
            }
        }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'Project-A'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
            Project = [pscustomobject]@{ Id = 'project-b-id'; Name = 'Project-B' }
        }
        $null = Get-GerberAdoPipelineDefinition -Context $context -PipelineId 42

        $script:capturedRelativePath | Should -Be 'project-b-id/_apis/pipelines/42'
    }
}
