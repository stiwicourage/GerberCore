BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'New-GerberAdoPolicyConfiguration' {
    It 'returns success when policy creation succeeds' {
        Mock Get-GerberAdoBranchRequestUri { [uri]'https://example.test/api' }
        Mock Build-GerberAdoPolicyBody { '{"type":"policy"}' }
        Mock Invoke-GerberAdoRestMutation {}

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'TestProj'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
        }
        $policy = [pscustomobject]@{
            Type = @{ id = 'type1' }
            Settings = @{ scope = @() }
        }
        $result = New-GerberAdoPolicyConfiguration -Context $context -RepoId 'r1' -Policy $policy -TeamId 't1'

        $result.Success | Should -BeTrue
    }

    It 'returns failure when policy creation throws exception' {
        Mock Get-GerberAdoBranchRequestUri { [uri]'https://example.test/api' }
        Mock Build-GerberAdoPolicyBody { throw [System.InvalidOperationException]::new('Error') }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'TestProj'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
        }
        $policy = [pscustomobject]@{
            Type = @{ id = 'type1' }
            Settings = @{ scope = @() }
        }
        $result = New-GerberAdoPolicyConfiguration -Context $context -RepoId 'r1' -Policy $policy -TeamId 't1'

        $result.Success | Should -BeFalse
    }

    It 'uses the selected project scope for policy creation when configuration points elsewhere' {
        $script:capturedRelativePath = $null
        Mock Get-GerberAdoBranchRequestUri {
            $script:capturedRelativePath = $RelativePath
            [uri]'https://example.test/api'
        }
        Mock Build-GerberAdoPolicyBody { '{"type":"policy"}' }
        Mock Invoke-GerberAdoRestMutation {}

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'Project-A'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
            Project = [pscustomobject]@{ Id = 'project-b-id'; Name = 'Project-B' }
        }
        $policy = [pscustomobject]@{
            Type = @{ id = 'type1' }
            Settings = @{ scope = @() }
        }
        $null = New-GerberAdoPolicyConfiguration -Context $context -RepoId 'r1' -Policy $policy -TeamId 't1'

        $script:capturedRelativePath | Should -Be 'project-b-id/_apis/policy/configurations'
    }
}

Describe 'Build-GerberAdoPolicyBody' {
    It 'updates scope with new repository ID' {
        $policy = [pscustomobject]@{
            Type = @{ id = 'type1' }
            Settings = @{
                scope = @(
                    @{ repositoryId = 'old-repo'; refName = 'refs/heads/main'; matchKind = 'exact' }
                )
            }
        }
        $result = Build-GerberAdoPolicyBody -Policy $policy -RepoId 'new-repo' -TeamId 't1'

        $result | Should -Match 'new-repo'
    }

    It 'adds team ID for auto-include reviewer policy' {
        $policy = [pscustomobject]@{
            Type = @{ id = 'fd2167ab-b0be-447a-8ec8-39368250530e' }
            Settings = @{
                scope = @(
                    @{ repositoryId = 'old-repo'; refName = 'refs/heads/main'; matchKind = 'exact' }
                )
            }
        }
        $result = Build-GerberAdoPolicyBody -Policy $policy -RepoId 'new-repo' -TeamId 'team-123'

        $result | Should -Match 'team-123'
    }
}
