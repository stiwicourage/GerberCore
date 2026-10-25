BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoPipelineList' {
    It 'returns list of pipelines' {
        Mock Get-GerberAdoBranchRequestUri { [uri]'https://example.test/api' }
        Mock Invoke-GerberAdoRestRequest {
            @{
                value = @(
                    @{ id = 1; name = 'Build' }
                    @{ id = 2; name = 'Deploy' }
                )
            }
        }

        $configuration = [pscustomobject]@{ ProjectName = 'TestProj'; CredentialIdentifier = 'PAT' }
        $result = Get-GerberAdoPipelineList -Configuration $configuration -Pat 'test-pat'

        $result.Count | Should -Be 2
        $result[0].Id | Should -Be 1
        $result[0].Name | Should -Be 'Build'
        $result[1].Id | Should -Be 2
        $result[1].Name | Should -Be 'Deploy'
    }

    It 'returns empty array when no pipelines exist' {
        Mock Get-GerberAdoBranchRequestUri { [uri]'https://example.test/api' }
        Mock Invoke-GerberAdoRestRequest {
            @{ value = @() }
        }

        $configuration = [pscustomobject]@{ ProjectName = 'TestProj'; CredentialIdentifier = 'PAT' }
        $result = Get-GerberAdoPipelineList -Configuration $configuration -Pat 'test-pat'

        $result.Count | Should -Be 0
    }
}
