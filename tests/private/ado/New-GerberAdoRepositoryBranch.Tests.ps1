BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'New-GerberAdoRepositoryBranch' {
    It 'returns <ExpectedResult> when branch creation <Scenario>' -ForEach @(
        @{
            Scenario = 'succeeds'
            ExpectedResult = 'success'
            CommitScript = { 'commit-sha' }
            ShouldSucceed = $true
        }
        @{
            Scenario = 'throws'
            ExpectedResult = 'failure'
            CommitScript = { throw [System.InvalidOperationException]::new('Error') }
            ShouldSucceed = $false
        }
    ) {
        Mock Get-GerberAdoBranchRequestUri { [uri]'https://example.test/api' }
        Mock Get-GerberAdoRepositoryBranchCommit $CommitScript
        Mock ConvertTo-Json { '{"name":"refs/heads/develop"}' }
        Mock Invoke-GerberAdoRestMutation {}

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'TestProj'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
        }
        $result = New-GerberAdoRepositoryBranch -Context $context -RepoId 'r1' -BranchRef 'refs/heads/develop' -DefaultBranchRef 'refs/heads/main'

        $result.Success | Should -Be $ShouldSucceed
    }

    It 'passes the DefaultBranchRef to Get-GerberAdoRepositoryBranchCommit' {
        Mock Get-GerberAdoBranchRequestUri { [uri]'https://example.test/api' }
        Mock Get-GerberAdoRepositoryBranchCommit { 'commit-sha' }
        Mock ConvertTo-Json { '{}' }
        Mock Invoke-GerberAdoRestMutation {}

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'TestProj'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
        }
        $null = New-GerberAdoRepositoryBranch -Context $context -RepoId 'r1' -BranchRef 'refs/heads/release' -DefaultBranchRef 'refs/heads/develop'

        Should -Invoke Get-GerberAdoRepositoryBranchCommit -Times 1 -ParameterFilter { $BranchRef -eq 'refs/heads/develop' }
    }

    It 'uses the selected project scope for branch creation when configuration points elsewhere' {
        $script:capturedRelativePath = $null
        Mock Get-GerberAdoBranchRequestUri {
            $script:capturedRelativePath = $RelativePath
            [uri]'https://example.test/api'
        }
        Mock Get-GerberAdoRepositoryBranchCommit { 'commit-sha' }
        Mock ConvertTo-Json { '{}' }
        Mock Invoke-GerberAdoRestMutation {}

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'Project-A'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
            Project = [pscustomobject]@{ Id = 'project-b-id'; Name = 'Project-B' }
        }
        $null = New-GerberAdoRepositoryBranch -Context $context -RepoId 'r1' -BranchRef 'refs/heads/release' -DefaultBranchRef 'refs/heads/develop'

        $script:capturedRelativePath | Should -Be 'project-b-id/_apis/git/repositories/r1/refs'
    }
}

Describe 'Get-GerberAdoRepositoryBranchCommit' {
    It 'returns commit SHA of the specified branch' {
        Mock Get-GerberAdoBranchRequestUri { [uri]'https://example.test/api' }
        Mock Invoke-GerberAdoRestRequest {
            @{
                value = @(
                    @{ objectId = 'develop-commit-sha' }
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
        $result = Get-GerberAdoRepositoryBranchCommit -Context $context -RepoId 'r1' -BranchRef 'refs/heads/develop'

        $result | Should -Be 'develop-commit-sha'
    }

    It 'strips the refs/ prefix when building the filter' {
        Mock Invoke-GerberAdoRestRequest {
            @{ value = @(@{ objectId = 'sha' }) }
        }
        Mock Get-GerberAdoBranchRequestUri { [uri]'https://example.test/api' }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'TestProj'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
        }
        $null = Get-GerberAdoRepositoryBranchCommit -Context $context -RepoId 'r1' -BranchRef 'refs/heads/develop'
        $null = Get-GerberAdoRepositoryBranchCommit -Context $context -RepoId 'r1' -BranchRef 'refs/heads/develop'
        Should -Invoke Get-GerberAdoBranchRequestUri -Times 1 -ParameterFilter { $Filter -eq 'heads/develop' }
        Should -Invoke Get-GerberAdoBranchRequestUri -Times 1 -ParameterFilter { $Filter -eq 'heads/develop' }
    }
    It 'uses the selected project scope for branch lookup when configuration points elsewhere' {
        $script:capturedRelativePath = $null
        Mock Invoke-GerberAdoRestRequest {
            @{ value = @(@{ objectId = 'sha' }) }
        }
        Mock Get-GerberAdoBranchRequestUri {
            $script:capturedRelativePath = $RelativePath
            [uri]'https://example.test/api'
        }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'Project-A'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
            Project = [pscustomobject]@{ Id = 'project-b-id'; Name = 'Project-B' }
        }
        $null = Get-GerberAdoRepositoryBranchCommit -Context $context -RepoId 'r1' -BranchRef 'refs/heads/develop'

        $script:capturedRelativePath | Should -Be 'project-b-id/_apis/git/repositories/r1/refs'
    }
}
