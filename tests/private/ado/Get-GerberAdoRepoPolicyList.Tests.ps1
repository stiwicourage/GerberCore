BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoRepoPolicyList' {
    It 'returns policies for the specified repository' {
        Mock Get-GerberAdoBranchRequestUri { [uri]'https://example.test/api' }
        Mock Invoke-GerberAdoRestRequest {
            @{
                value = @(
                    @{
                        id = 1
                        type = @{ id = 'type1' }
                        settings = @{
                            scope = @(
                                @{ repositoryId = 'r1' }
                            )
                        }
                    }
                    @{
                        id = 2
                        type = @{ id = 'type2' }
                        settings = @{
                            scope = @(
                                @{ repositoryId = 'r2' }
                            )
                        }
                    }
                )
            }
        }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'TestProj'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
        }
        $result = Get-GerberAdoRepoPolicyList -Context $context -RepoId 'r1'

        $result.Count | Should -Be 1
        $result[0].Id | Should -Be 1
    }

    It 'returns empty array when no policies exist for repository' {
        Mock Get-GerberAdoBranchRequestUri { [uri]'https://example.test/api' }
        Mock Invoke-GerberAdoRestRequest {
            @{ value = @() }
        }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'TestProj'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
        }
        $result = Get-GerberAdoRepoPolicyList -Context $context -RepoId 'r1'

        $result.Count | Should -Be 0
    }

    It 'uses the selected project scope for policy lookups when configuration points elsewhere' {
        $script:capturedRelativePath = $null
        Mock Get-GerberAdoBranchRequestUri {
            $script:capturedRelativePath = $RelativePath
            [uri]'https://example.test/api'
        }
        Mock Invoke-GerberAdoRestRequest { @{ value = @() } }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'Project-A'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
            Project = [pscustomobject]@{ Id = 'project-b-id'; Name = 'Project-B' }
        }
        $null = Get-GerberAdoRepoPolicyList -Context $context -RepoId 'r1'

        $script:capturedRelativePath | Should -Be 'project-b-id/_apis/policy/configurations'
    }
}

Describe 'Test-GerberAdoPolicyForRepo' {
    It 'returns true when policy applies to repository' {
        $policy = @{
            settings = @{
                scope = @(
                    @{ repositoryId = 'r1' }
                )
            }
        }

        $result = Test-GerberAdoPolicyForRepo -Policy $policy -RepoId 'r1'

        $result | Should -BeTrue
    }

    It 'returns false when policy does not apply to repository' {
        $policy = @{
            settings = @{
                scope = @(
                    @{ repositoryId = 'r2' }
                )
            }
        }

        $result = Test-GerberAdoPolicyForRepo -Policy $policy -RepoId 'r1'

        $result | Should -BeFalse
    }
}
