BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoRepositoryBranchList' {
    It 'returns branch ref names from ADO response' {
        Mock Get-GerberAdoBranchRequestUri { [uri]'https://example.test/api' }
        Mock Invoke-GerberAdoRestRequest {
            @{
                value = @(
                    @{ name = 'refs/heads/develop' }
                    @{ name = 'refs/heads/release' }
                    @{ name = 'refs/heads/main' }
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
        $result = @(Get-GerberAdoRepositoryBranchList -Context $context -RepoId 'r1')

        $result.Count | Should -Be 3
        $result[0] | Should -Be 'refs/heads/develop'
        $result[1] | Should -Be 'refs/heads/release'
        $result[2] | Should -Be 'refs/heads/main'
    }

    It 'returns all refs without filtering any out' {
        Mock Get-GerberAdoBranchRequestUri { [uri]'https://example.test/api' }
        Mock Invoke-GerberAdoRestRequest {
            @{
                value = @(
                    @{ name = 'refs/heads/feature/x' }
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
        $result = @(Get-GerberAdoRepositoryBranchList -Context $context -RepoId 'r1')

        $result.Count | Should -Be 1
        $result[0] | Should -Be 'refs/heads/feature/x'
    }

    It 'returns empty array when no branches exist' {
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
        $result = @(Get-GerberAdoRepositoryBranchList -Context $context -RepoId 'r1')

        $result.Count | Should -Be 0
    }

    It 'uses the selected project scope when configuration points elsewhere' {
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
        $null = @(Get-GerberAdoRepositoryBranchList -Context $context -RepoId 'r1')

        $script:capturedRelativePath | Should -Be 'project-b-id/_apis/git/repositories/r1/refs'
    }
}
