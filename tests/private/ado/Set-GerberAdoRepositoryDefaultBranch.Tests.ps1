BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Set-GerberAdoRepositoryDefaultBranch' {
    It 'calls Invoke-GerberAdoRestMutation with Patch method and returns Success=true' {
        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName             = 'P'
                DefaultApiVersion       = '7.0'
                CredentialIdentifier  = 'PAT'
                CollectionUri           = [uri]'https://ado.example.com/org/'
            }
            Pat          = 'test-pat'
            TargetBranch = 'refs/heads/main'
        }
        $repoItem = [pscustomobject]@{ RepoId = 'r1'; RepoName = 'Alpha' }
        Mock Invoke-GerberAdoRestMutation {}

        $result = Set-GerberAdoRepositoryDefaultBranch -Context $context -RepoItem $repoItem

        $result.Success | Should -BeTrue
        $result.RepoName | Should -Be 'Alpha'
        Should -Invoke Invoke-GerberAdoRestMutation -Times 1 -ParameterFilter {
            $MutationContext.Method -eq 'Patch'
        }
    }

    It 'returns Success=false when Invoke-GerberAdoRestMutation throws' {
        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName             = 'P'
                DefaultApiVersion       = '7.0'
                CredentialIdentifier  = 'PAT'
                CollectionUri           = [uri]'https://ado.example.com/org/'
            }
            Pat          = 'test-pat'
            TargetBranch = 'refs/heads/main'
        }
        $repoItem = [pscustomobject]@{ RepoId = 'r1'; RepoName = 'Beta' }
        Mock Invoke-GerberAdoRestMutation { throw [System.Exception]::new('Network failure') }

        $result = Set-GerberAdoRepositoryDefaultBranch -Context $context -RepoItem $repoItem

        $result.Success | Should -BeFalse
        $result.RepoName | Should -Be 'Beta'
    }
}

Describe 'Get-GerberAdoRepositoryPatchUri' {
    It 'produces a URI with the correct repository path and api-version' {
        $config = [pscustomobject]@{
            ProjectName             = 'MyProject'
            DefaultApiVersion       = '7.0'
            CredentialIdentifier  = 'PAT'
            CollectionUri           = [uri]'https://ado.example.com/org/'
        }

        $uri = Get-GerberAdoRepositoryPatchUri -Configuration $config -RepoId 'abc-123'

        $uri.AbsoluteUri | Should -BeLike '*MyProject/_apis/git/repositories/abc-123*'
        $uri.AbsoluteUri | Should -BeLike '*api-version=7.0*'
    }

    It 'includes the RepoId in the URI path' {
        $config = [pscustomobject]@{
            ProjectName             = 'P'
            DefaultApiVersion       = '7.0'
            CredentialIdentifier  = 'PAT'
            CollectionUri           = [uri]'https://ado.example.com/org/'
        }

        $uri = Get-GerberAdoRepositoryPatchUri -Configuration $config -RepoId 'repo-xyz'

        $uri.AbsoluteUri | Should -BeLike '*repo-xyz*'
    }

    It 'uses the provided project scope instead of the configured default project' {
        $config = [pscustomobject]@{
            ProjectName             = 'Project-A'
            DefaultApiVersion       = '7.0'
            CredentialIdentifier  = 'PAT'
            CollectionUri           = [uri]'https://ado.example.com/org/'
        }

        $uri = Get-GerberAdoRepositoryPatchUri -Configuration $config -RepoId 'repo-xyz' -ProjectScope 'project-b-id'

        $uri.AbsoluteUri | Should -BeLike '*project-b-id/_apis/git/repositories/repo-xyz*'
        $uri.AbsoluteUri | Should -Not -BeLike '*Project-A/_apis/git/repositories/repo-xyz*'
    }
}

Describe 'Build-GerberAdoRepositoryDefaultBranchBody' {
    It 'returns JSON containing the defaultBranch key with the target branch value' {
        $body = Build-GerberAdoRepositoryDefaultBranchBody -TargetBranch 'refs/heads/develop'

        $parsed = $body | ConvertFrom-Json
        $parsed.defaultBranch | Should -Be 'refs/heads/develop'
    }

    It 'returns compressed JSON' {
        $body = Build-GerberAdoRepositoryDefaultBranchBody -TargetBranch 'refs/heads/main'

        $body | Should -Not -Match '[\r\n]'
        $body | Should -Not -Match '  '
    }
}
