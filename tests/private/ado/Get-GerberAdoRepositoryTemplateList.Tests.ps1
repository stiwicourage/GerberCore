BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoRepositoryTemplateList' {
    It 'returns repositories matching Template_* pattern' {
        Mock Get-GerberAdoBranchRequestUri { [uri]'https://example.test/api' }
        Mock Invoke-GerberAdoRestRequest {
            @{
                value = @(
                    @{ id = 't1'; name = 'Template_NuGet'; isDisabled = $false; defaultBranch = 'refs/heads/develop' }
                    @{ id = 't2'; name = 'Template_Web'; isDisabled = $false; defaultBranch = 'refs/heads/main' }
                    @{ id = 'r1'; name = 'Regular'; isDisabled = $false; defaultBranch = 'refs/heads/main' }
                )
            }
        }

        $configuration = [pscustomobject]@{ ProjectName = 'TestProj'; CredentialIdentifier = 'PAT' }
        $result = Get-GerberAdoRepositoryTemplateList -Configuration $configuration -Pat 'test-pat' -ProjectName 'TestProj'

        $result.Count | Should -Be 2
        $result[0].Name | Should -Be 'Template_NuGet'
        $result[1].Name | Should -Be 'Template_Web'
    }

    It 'returns DefaultBranch for each template' {
        Mock Get-GerberAdoBranchRequestUri { [uri]'https://example.test/api' }
        Mock Invoke-GerberAdoRestRequest {
            @{
                value = @(
                    @{ id = 't1'; name = 'Template_NuGet'; isDisabled = $false; defaultBranch = 'refs/heads/develop' }
                    @{ id = 't2'; name = 'Template_Web'; isDisabled = $false; defaultBranch = 'refs/heads/main' }
                )
            }
        }

        $configuration = [pscustomobject]@{ ProjectName = 'TestProj'; CredentialIdentifier = 'PAT' }
        $result = Get-GerberAdoRepositoryTemplateList -Configuration $configuration -Pat 'test-pat' -ProjectName 'TestProj'

        $result[0].DefaultBranch | Should -Be 'refs/heads/develop'
        $result[1].DefaultBranch | Should -Be 'refs/heads/main'
    }

    It 'excludes disabled repositories' {
        Mock Get-GerberAdoBranchRequestUri { [uri]'https://example.test/api' }
        Mock Invoke-GerberAdoRestRequest {
            @{
                value = @(
                    @{ id = 't1'; name = 'Template_NuGet'; isDisabled = $true; defaultBranch = 'refs/heads/develop' }
                    @{ id = 't2'; name = 'Template_Web'; isDisabled = $false; defaultBranch = 'refs/heads/main' }
                )
            }
        }

        $configuration = [pscustomobject]@{ ProjectName = 'TestProj'; CredentialIdentifier = 'PAT' }
        $result = Get-GerberAdoRepositoryTemplateList -Configuration $configuration -Pat 'test-pat' -ProjectName 'TestProj'

        $result.Count | Should -Be 1
        $result[0].Name | Should -Be 'Template_Web'
    }

    It 'returns empty array when no templates exist' {
        Mock Get-GerberAdoBranchRequestUri { [uri]'https://example.test/api' }
        Mock Invoke-GerberAdoRestRequest {
            @{ value = @() }
        }

        $configuration = [pscustomobject]@{ ProjectName = 'TestProj'; CredentialIdentifier = 'PAT' }
        $result = Get-GerberAdoRepositoryTemplateList -Configuration $configuration -Pat 'test-pat' -ProjectName 'TestProj'

        $result.Count | Should -Be 0
    }
}
