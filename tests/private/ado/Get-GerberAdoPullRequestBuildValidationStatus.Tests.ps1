BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot

    function Get-BuildValidationContext {
        return [pscustomobject]@{
            Pat = 'pat'
            Configuration = [pscustomobject]@{
                CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                DefaultApiVersion = '7.0'
                PolicyEvaluationApiVersion = '7.1-preview.1'
                CredentialIdentifier = 'gerber:ado:example:pat'
            }
        }
    }

    function Get-BuildValidationPullRequest {
        param(
            [string]$MergeStatus = ''
        )

        return [pscustomobject]@{
            PullRequestId = 18075
            ProjectName = 'ExampleProject'
            ProjectId = 'project-id'
            RepositoryId = 'repo-id'
            MergeStatus = $MergeStatus
        }
    }

    function Invoke-BuildValidationStatusUnderTest {
        param(
            [string]$MergeStatus = ''
        )

        return Get-GerberAdoPullRequestBuildValidationStatus `
            -Context (Get-BuildValidationContext) `
            -PullRequest (Get-BuildValidationPullRequest -MergeStatus $MergeStatus)
    }
}

Describe 'Get-GerberAdoPullRequestBuildValidationStatus' {
    BeforeEach {
        Mock Get-GerberAdoApiUri { [uri]'https://ado.example.test/test' }
    }

    It 'returns pull request statuses when Azure DevOps responds successfully' {
        Mock Invoke-GerberAdoRestRequest {
            @{
                value = @(
                    @{
                        state = 'succeeded'
                        description = 'Build passed'
                        context = @{ name = 'CI build' }
                    }
                )
            }
        }

        $result = Invoke-BuildValidationStatusUnderTest

        $result.IsAvailable | Should -BeTrue
        $result.StatusList[0].ContextName | Should -Be 'CI build'
    }

    It 'falls back to policy checks and merge status when the statuses endpoint is empty' {
        Mock Invoke-GerberAdoRestRequest { @{ value = @() } }
        Mock Get-GerberAdoPullRequestPolicyEvaluationList {
            @(
                [pscustomobject]@{
                    DisplayName = 'Build'
                    TypeId = 'policy-type-id'
                    Status = 'approved'
                    IsBlocking = $true
                    IsEnabled = $true
                }
                [pscustomobject]@{
                    DisplayName = 'Minimum number of reviewers'
                    TypeId = 'fa4e907d-c16b-452d-8106-7efa0cb84489'
                    Status = 'queued'
                    IsBlocking = $true
                    IsEnabled = $true
                }
            )
        }

        $result = Invoke-BuildValidationStatusUnderTest -MergeStatus 'succeeded'

        $result.IsAvailable | Should -BeTrue
        $result.StatusList.Count | Should -Be 2
        $result.StatusList[0].Description | Should -Be 'All required checks succeeded.'
        $result.StatusList[1].Description | Should -Be 'No merge conflicts.'
    }

    It 'surfaces failed blocking checks from policy evaluations when the statuses endpoint is empty' {
        Mock Invoke-GerberAdoRestRequest { @{ value = @() } }
        Mock Get-GerberAdoPullRequestPolicyEvaluationList {
            @(
                [pscustomobject]@{
                    DisplayName = 'Build'
                    TypeId = 'policy-type-id'
                    Status = 'rejected'
                    IsBlocking = $true
                    IsEnabled = $true
                }
            )
        }

        $result = Invoke-BuildValidationStatusUnderTest -MergeStatus 'queued'

        $result.StatusList[0].State | Should -Be 'failed'
        $result.StatusList[0].Description | Should -Be 'Required checks failed: Build (rejected).'
        $result.StatusList[1].Description | Should -Be 'Merge validation is still running.'
    }

    It 'returns an unavailable result when the status request fails' {
        Mock Invoke-GerberAdoRestRequest { throw [System.ArgumentException]::new('Failed') }

        $result = Invoke-BuildValidationStatusUnderTest

        $result.IsAvailable | Should -BeFalse
        $result.ErrorMessage | Should -Be 'Failed'
    }
}

Describe 'Get-GerberAdoBuildValidationFallbackStatusList' {
    It 'ignores policy-evaluation failures and still returns merge status entries' {
        Mock Get-GerberAdoPullRequestPolicyEvaluationList { throw [System.ArgumentException]::new('Policy failure') }

        $result = Get-GerberAdoBuildValidationFallbackStatusList `
            -Context ([pscustomobject]@{}) `
            -PullRequest ([pscustomobject]@{ MergeStatus = 'queued' })

        @($result | Where-Object { $null -ne $_ }).Count | Should -Be 1
        @($result | Where-Object { $null -ne $_ })[0].Description | Should -Be 'Merge validation is still running.'
    }
}

Describe 'Get-GerberAdoPolicyStatusEntryOrNull' {
    It 'returns null when there are no relevant blocking policy evaluations' {
        $result = Get-GerberAdoPolicyStatusEntryOrNull -PolicyEvaluationList @(
            [pscustomobject]@{
                DisplayName = 'Minimum number of reviewers'
                TypeId = 'fa4e907d-c16b-452d-8106-7efa0cb84489'
                Status = 'queued'
                IsBlocking = $true
                IsEnabled = $true
            }
        )

        $result | Should -BeNull
    }

    It 'returns a pending status when required checks are still running' {
        $result = Get-GerberAdoPolicyStatusEntryOrNull -PolicyEvaluationList @(
            [pscustomobject]@{
                DisplayName = 'Build'
                TypeId = 'policy-type-id'
                Status = 'queued'
                IsBlocking = $true
                IsEnabled = $true
            }
        )

        $result.State | Should -Be 'pending'
        $result.Description | Should -Be 'Required checks are still pending: Build (queued).'
    }

    It 'formats unique policy labels and falls back to Policy for blank display names' {
        $result = Format-GerberAdoPolicyEvaluationList -PolicyEvaluationList @(
            [pscustomobject]@{ DisplayName = ''; Status = 'queued' }
            [pscustomobject]@{ DisplayName = 'Build'; Status = 'approved' }
            [pscustomobject]@{ DisplayName = 'Build'; Status = 'approved' }
        )

        $result | Should -Be 'Policy (queued), Build (approved)'
    }
}

Describe 'Get-GerberAdoMergeStatusEntryOrNull' {
    It 'returns null when merge status is blank or unsupported' {
        (Get-GerberAdoMergeStatusEntryOrNull -MergeStatus '') | Should -BeNull
        (Get-GerberAdoMergeStatusEntryOrNull -MergeStatus 'mystery') | Should -BeNull
    }

    It 'maps failure-style merge states to synthetic status messages' {
        (Get-GerberAdoMergeStatusEntryOrNull -MergeStatus 'conflicts').Description | Should -Be 'Merge conflicts detected.'
        (Get-GerberAdoMergeStatusEntryOrNull -MergeStatus 'failure').Description | Should -Be 'Azure DevOps could not calculate merge status.'
        (Get-GerberAdoMergeStatusEntryOrNull -MergeStatus 'rejectedbypolicy').Description | Should -Be 'Merge is currently blocked by policy.'
        (Get-GerberAdoMergeStatusEntryOrNull -MergeStatus 'notset').Description | Should -Be 'Merge validation has not started yet.'
    }
}
