BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'New-GerberAdoRepository' {
    It 'returns success with repository ID when creation succeeds' {
        Mock Get-GerberAdoBranchRequestUri { [uri]'https://example.test/api' }
        Mock Get-GerberHttpConfiguration { [pscustomobject]@{ ConnectionTimeoutSeconds = 5; OperationTimeoutSeconds = 15 } }
        Mock Get-GerberAdoRequestHeader { @{ Authorization = 'Bearer test' } }
        Mock Invoke-RestMethod { @{ id = 'new-repo-id' } }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'TestProj'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
            RepositoryName = 'TestRepo'
            Project = [pscustomobject]@{ Id = 'p1' }
        }
        $result = New-GerberAdoRepository -Context $context

        $result.Success | Should -BeTrue
        $result.RepoId | Should -Be 'new-repo-id'
    }

    It 'returns failure when creation throws exception' {
        Mock Get-GerberAdoBranchRequestUri { [uri]'https://example.test/api' }
        Mock Get-GerberHttpConfiguration { [pscustomobject]@{ ConnectionTimeoutSeconds = 5; OperationTimeoutSeconds = 15 } }
        Mock Get-GerberAdoRequestHeader { @{ Authorization = 'Bearer test' } }
        Mock Invoke-RestMethod { throw [System.InvalidOperationException]::new('API error') }
        Mock Get-GerberAdoRequestFailureMessage { 'Error message' }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'TestProj'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
            RepositoryName = 'TestRepo'
            Project = [pscustomobject]@{ Id = 'p1' }
        }
        $result = New-GerberAdoRepository -Context $context

        $result.Success | Should -BeFalse
        $result.RepoId | Should -Be ''
    }

    It 'returns failure with the raw exception message when the URI cannot be built' {
        Mock Get-GerberAdoBranchRequestUri { throw [System.InvalidOperationException]::new('URI build failed') }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'TestProj'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
            RepositoryName = 'TestRepo'
            Project = [pscustomobject]@{ Id = 'p1' }
        }
        $result = New-GerberAdoRepository -Context $context

        $result.Success | Should -BeFalse
        $result.RepoId | Should -Be ''
        $result.ErrorDetail | Should -Be 'URI build failed'
    }

    It 'uses the selected project scope for both the repository endpoint and body when configuration points elsewhere' {
        $script:capturedRelativePath = $null
        $script:capturedBody = $null
        Mock Get-GerberAdoBranchRequestUri {
            $script:capturedRelativePath = $RelativePath
            [uri]'https://example.test/api'
        }
        Mock Get-GerberHttpConfiguration { [pscustomobject]@{ ConnectionTimeoutSeconds = 5; OperationTimeoutSeconds = 15 } }
        Mock Get-GerberAdoRequestHeader { @{ Authorization = '******' } }
        Mock ConvertTo-Json {
            $script:capturedBody = $InputObject
            '{"name":"TestRepo"}'
        }
        Mock Invoke-RestMethod { @{ id = 'new-repo-id' } }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'Project-A'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
            RepositoryName = 'TestRepo'
            Project = [pscustomobject]@{ Id = 'project-b-id'; Name = 'Project-B' }
        }
        $null = New-GerberAdoRepository -Context $context

        $script:capturedRelativePath | Should -Be 'project-b-id/_apis/git/repositories'
        $script:capturedBody.project.id | Should -Be 'project-b-id'
    }
}
