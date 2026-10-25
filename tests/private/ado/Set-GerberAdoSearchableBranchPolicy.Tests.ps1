BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Set-GerberAdoSearchableBranchPolicy' {
    It 'calls create flow and returns Success=true IsCreate=true when PolicyId is null' {
        Mock Invoke-GerberAdoRestMutation {}

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName          = 'P'
                DefaultApiVersion    = '7.1'
                CredentialIdentifier = 'PAT'
                CollectionUri        = [uri]'https://ado.example.com/org/'
            }
            Pat = 'test-pat'
        }
        $policyItem = [pscustomobject]@{
            RepoId   = 'r1'
            RepoName = 'Alpha'
            PolicyId = $null
            NewScope = @('refs/heads/main')
        }
        $result = Set-GerberAdoSearchableBranchPolicy -Context $context -PolicyItem $policyItem

        $result.Success | Should -BeTrue
        $result.IsCreate | Should -BeTrue
        $result.RepoName | Should -Be 'Alpha'
        Should -Invoke Invoke-GerberAdoRestMutation -Times 1 -ParameterFilter {
            $MutationContext.Method -eq 'Post'
        }
    }

    It 'calls update flow and returns Success=true IsCreate=false when PolicyId is non-null' {
        Mock Invoke-GerberAdoRestMutation {}

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName          = 'P'
                DefaultApiVersion    = '7.1'
                CredentialIdentifier = 'PAT'
                CollectionUri        = [uri]'https://ado.example.com/org/'
            }
            Pat = 'test-pat'
        }
        $policyItem = [pscustomobject]@{
            RepoId   = 'r1'
            RepoName = 'Beta'
            PolicyId = '99'
            NewScope = @('refs/heads/main')
        }
        $result = Set-GerberAdoSearchableBranchPolicy -Context $context -PolicyItem $policyItem

        $result.Success | Should -BeTrue
        $result.IsCreate | Should -BeFalse
        $result.RepoName | Should -Be 'Beta'
        Should -Invoke Invoke-GerberAdoRestMutation -Times 1 -ParameterFilter {
            $MutationContext.Method -eq 'Put'
        }
    }

    It 'returns Success=false when Invoke-GerberAdoRestMutation throws' {
        Mock Invoke-GerberAdoRestMutation { throw [System.Exception]::new('Network failure') }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName          = 'P'
                DefaultApiVersion    = '7.1'
                CredentialIdentifier = 'PAT'
                CollectionUri        = [uri]'https://ado.example.com/org/'
            }
            Pat = 'test-pat'
        }
        $policyItem = [pscustomobject]@{
            RepoId   = 'r1'
            RepoName = 'Gamma'
            PolicyId = $null
            NewScope = @()
        }
        $result = Set-GerberAdoSearchableBranchPolicy -Context $context -PolicyItem $policyItem

        $result.Success | Should -BeFalse
        $result.RepoName | Should -Be 'Gamma'
    }
}

Describe 'Build-GerberAdoSearchableBranchPolicyBody' {
    It 'does not include an id field when PolicyId is null' {
        $policyItem = [pscustomobject]@{ RepoId = 'r1'; NewScope = @('refs/heads/main') }
        $body = Build-GerberAdoSearchableBranchPolicyBody -PolicyItem $policyItem

        $parsed = $body | ConvertFrom-Json
        $parsed.PSObject.Properties.Name | Should -Not -Contain 'id'
    }

    It 'includes an integer id field when PolicyId is non-empty' {
        $policyItem = [pscustomobject]@{ RepoId = 'r1'; NewScope = @('refs/heads/main') }
        $body = Build-GerberAdoSearchableBranchPolicyBody -PolicyItem $policyItem -PolicyId '42'

        $parsed = $body | ConvertFrom-Json
        $parsed.id | Should -Be 42
    }

    It 'sets isEnabled=true and isBlocking=false' {
        $policyItem = [pscustomobject]@{ RepoId = 'r1'; NewScope = @() }
        $body = Build-GerberAdoSearchableBranchPolicyBody -PolicyItem $policyItem

        $parsed = $body | ConvertFrom-Json
        $parsed.isEnabled | Should -BeTrue
        $parsed.isBlocking | Should -BeFalse
    }

    It 'serializes settings.scope as an array with only repositoryId and no refName' {
        $policyItem = [pscustomobject]@{
            RepoId   = 'repo-1'
            NewScope = @('refs/heads/main', 'refs/heads/dev')
        }
        $body = Build-GerberAdoSearchableBranchPolicyBody -PolicyItem $policyItem

        $parsed = $body | ConvertFrom-Json
        @($parsed.settings.scope).Count | Should -Be 1
        $parsed.settings.scope[0].repositoryId | Should -Be 'repo-1'
        $parsed.settings.scope[0].PSObject.Properties.Name | Should -Not -Contain 'refName'
    }

    It 'serializes settings.searchBranches as a string array of branch names' {
        $policyItem = [pscustomobject]@{
            RepoId   = 'repo-1'
            NewScope = @('refs/heads/main', 'refs/heads/dev')
        }
        $body = Build-GerberAdoSearchableBranchPolicyBody -PolicyItem $policyItem

        $parsed = $body | ConvertFrom-Json
        @($parsed.settings.searchBranches).Count | Should -Be 2
        $parsed.settings.searchBranches | Should -Contain 'refs/heads/main'
        $parsed.settings.searchBranches | Should -Contain 'refs/heads/dev'
    }

    It 'includes the correct policy type id' {
        $policyItem = [pscustomobject]@{ RepoId = 'r1'; NewScope = @() }
        $body = Build-GerberAdoSearchableBranchPolicyBody -PolicyItem $policyItem

        $parsed = $body | ConvertFrom-Json
        $parsed.type.id | Should -Be '0517f88d-4ec5-4343-9d26-9930ebd53069'
    }
}

Describe 'Get-GerberAdoSearchableBranchPolicyWriteUri' {
    It 'returns a policy configurations URI when PolicyId is null' {
        $config = [pscustomobject]@{
            ProjectName       = 'MyProject'
            DefaultApiVersion = '7.1'
            CollectionUri     = [uri]'https://ado.example.com/org/'
        }
        $uri = Get-GerberAdoSearchableBranchPolicyWriteUri -Configuration $config

        $uri.AbsoluteUri | Should -BeLike '*MyProject/_apis/policy/configurations*'
        $uri.AbsoluteUri | Should -BeLike '*api-version=7.1*'
    }

    It 'appends the PolicyId to the path when provided' {
        $config = [pscustomobject]@{
            ProjectName       = 'MyProject'
            DefaultApiVersion = '7.1'
            CollectionUri     = [uri]'https://ado.example.com/org/'
        }
        $uri = Get-GerberAdoSearchableBranchPolicyWriteUri -Configuration $config -PolicyId '77'

        $uri.AbsoluteUri | Should -BeLike '*_apis/policy/configurations/77*'
    }

    It 'includes api-version in the query string for both create and update URIs' {
        $config = [pscustomobject]@{
            ProjectName       = 'P'
            DefaultApiVersion = '7.2'
            CollectionUri     = [uri]'https://ado.example.com/org/'
        }

        $createUri = Get-GerberAdoSearchableBranchPolicyWriteUri -Configuration $config
        $updateUri = Get-GerberAdoSearchableBranchPolicyWriteUri -Configuration $config -PolicyId '10'

        $createUri.AbsoluteUri | Should -BeLike '*api-version=7.2*'
        $updateUri.AbsoluteUri | Should -BeLike '*api-version=7.2*'
    }
}
