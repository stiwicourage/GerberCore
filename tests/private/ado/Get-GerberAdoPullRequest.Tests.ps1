BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoPullRequest' {
    It 'returns pull request metadata from Azure DevOps' {
        Mock Get-GerberAdoApiUri { [uri]'https://ado.example.test/test' }
        Mock Invoke-GerberAdoRestRequest {
            [pscustomobject]@{
                pullRequestId = 18075
                title = 'Review me'
                sourceRefName = 'refs/heads/feature'
                targetRefName = 'refs/heads/main'
                status = 'active'
                url = 'https://ado.example.test/pr/18075'
                repository = [pscustomobject]@{
                    id = 'repo-id'
                    name = 'Repo'
                    project = [pscustomobject]@{
                        id = 'project-id'
                    }
                }
                lastMergeSourceCommit = [pscustomobject]@{
                    commitId = 'abc123'
                }
                mergeStatus = 'succeeded'
            }
        }

        $result = Get-GerberAdoPullRequest `
            -Configuration ([pscustomobject]@{ CollectionUri = [uri]'https://ado.example.test/ExampleProject/'; DefaultApiVersion = '7.0'; CredentialIdentifier = 'gerber:ado:example:pat' }) `
            -Pat 'pat' `
            -PullRequestReference ([pscustomobject]@{ PullRequestId = 18075; ProjectName = 'ExampleProject'; RepositoryName = 'Repo' })

        $result.PullRequestId | Should -Be 18075
        $result.ProjectId | Should -Be 'project-id'
        $result.RepositoryId | Should -Be 'repo-id'
        $result.SourceCommitId | Should -Be 'abc123'
        $result.MergeStatus | Should -Be 'succeeded'
    }

    It 'throws when the URL repository does not match the resolved pull request repository' {
        Mock Get-GerberAdoApiUri { [uri]'https://ado.example.test/test' }
        Mock Invoke-GerberAdoRestRequest {
            [pscustomobject]@{
                pullRequestId = 18075
                repository = [pscustomobject]@{
                    id = 'repo-id'
                    name = 'OtherRepo'
                    project = [pscustomobject]@{
                        id = 'project-id'
                    }
                }
                lastMergeSourceCommit = [pscustomobject]@{
                    commitId = 'abc123'
                }
            }
        }

        {
            Get-GerberAdoPullRequest `
                -Configuration ([pscustomobject]@{ CollectionUri = [uri]'https://ado.example.test/ExampleProject/'; DefaultApiVersion = '7.0'; CredentialIdentifier = 'gerber:ado:example:pat' }) `
                -Pat 'pat' `
                -PullRequestReference ([pscustomobject]@{ PullRequestId = 18075; ProjectName = 'ExampleProject'; RepositoryName = 'Repo' })
        } | Should -Throw "*did not match*"
    }

    It 'throws when Azure DevOps does not return a project id for the pull request repository' {
        Mock Get-GerberAdoApiUri { [uri]'https://ado.example.test/test' }
        Mock Invoke-GerberAdoRestRequest {
            [pscustomobject]@{
                pullRequestId = 18075
                repository = [pscustomobject]@{
                    id = 'repo-id'
                    name = 'Repo'
                }
                lastMergeSourceCommit = [pscustomobject]@{
                    commitId = 'abc123'
                }
            }
        }

        {
            Get-GerberAdoPullRequest `
                -Configuration ([pscustomobject]@{ CollectionUri = [uri]'https://ado.example.test/ExampleProject/'; DefaultApiVersion = '7.0'; CredentialIdentifier = 'gerber:ado:example:pat' }) `
                -Pat 'pat' `
                -PullRequestReference ([pscustomobject]@{ PullRequestId = 18075; ProjectName = 'ExampleProject'; RepositoryName = 'Repo' })
        } | Should -Throw "*project details*"
    }

    It 'throws when Azure DevOps does not return repository details for the pull request' {
        Mock Get-GerberAdoApiUri { [uri]'https://ado.example.test/test' }
        Mock Invoke-GerberAdoRestRequest {
            [pscustomobject]@{
                pullRequestId = 18075
                repository = $null
            }
        }

        {
            Get-GerberAdoPullRequest `
                -Configuration ([pscustomobject]@{ CollectionUri = [uri]'https://ado.example.test/ExampleProject/'; DefaultApiVersion = '7.0'; CredentialIdentifier = 'gerber:ado:example:pat' }) `
                -Pat 'pat' `
                -PullRequestReference ([pscustomobject]@{ PullRequestId = 18075; ProjectName = 'ExampleProject'; RepositoryName = 'Repo' })
        } | Should -Throw "*repository details*"
    }
}
