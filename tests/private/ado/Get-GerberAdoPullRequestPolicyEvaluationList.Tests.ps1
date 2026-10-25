BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoPullRequestPolicyEvaluationList' {
    It 'requests policy evaluations with the code review artifact id and maps the response' {
        Mock Get-GerberAdoApiUri { [uri]'https://ado.example.test/test' }
        Mock Invoke-GerberAdoRestRequest {
            @{
                value = @(
                    @{
                        status = 'approved'
                        configuration = @{
                            isBlocking = $true
                            isEnabled = $true
                            type = @{
                                displayName = 'Build'
                                id = 'policy-type-id'
                            }
                        }
                    }
                )
            }
        }

        $result = Get-GerberAdoPullRequestPolicyEvaluationList `
            -Context ([pscustomobject]@{
                Pat = 'pat'
                Configuration = [pscustomobject]@{
                    CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                    PolicyEvaluationApiVersion = '7.1-preview.1'
                    CredentialIdentifier = 'gerber:ado:example:pat'
                }
            }) `
            -PullRequest ([pscustomobject]@{
                PullRequestId = 18075
                ProjectId = 'project-id'
                ProjectName = 'ExampleProject'
            })

        $result.Count | Should -Be 1
        $result[0].DisplayName | Should -Be 'Build'
        $result[0].Status | Should -Be 'approved'
        $result[0].IsBlocking | Should -BeTrue
        Assert-MockCalled Get-GerberAdoApiUri -Times 1 -Exactly -ParameterFilter {
            $QueryParameterMap.artifactId -eq 'vstfs:///CodeReview/CodeReviewId/project-id/18075' -and
            $QueryParameterMap['api-version'] -eq '7.1-preview.1'
        }
    }

    It 'returns an empty list when the pull request does not include a project id' {
        $result = Get-GerberAdoPullRequestPolicyEvaluationList `
            -Context ([pscustomobject]@{
                Pat = 'pat'
                Configuration = [pscustomobject]@{
                    CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                    PolicyEvaluationApiVersion = '7.1-preview.1'
                    CredentialIdentifier = 'gerber:ado:example:pat'
                }
            }) `
            -PullRequest ([pscustomobject]@{
                PullRequestId = 18075
                ProjectId = ''
                ProjectName = 'ExampleProject'
            })

        @($result).Count | Should -Be 0
    }
}
