BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberSearchableBranchPolicyTypeId' {
    It 'returns the correct searchable-branch policy type GUID' {
        $result = Get-GerberSearchableBranchPolicyTypeId

        $result | Should -Be '0517f88d-4ec5-4343-9d26-9930ebd53069'
    }
}

Describe 'Get-GerberAdoSearchableBranchPolicyReport' {
    It 'returns a report with RepoList, CreateList, UpdateList, and AlreadyAlignedList' {
        Mock Get-GerberAdoRepositoryList { @() }
        Mock Get-GerberAdoSearchableBranchPolicyMap { @{} }
        Mock Invoke-GerberSearchableBranchRepoScan {
            [pscustomobject]@{
                CreateList  = [System.Collections.Generic.List[pscustomobject]]::new()
                UpdateList  = [System.Collections.Generic.List[pscustomobject]]::new()
                AlignedList = [System.Collections.Generic.List[pscustomobject]]::new()
            }
        }

        $context = [pscustomobject]@{
            Configuration     = [pscustomobject]@{ CredentialIdentifier = 'PAT' }
            Pat               = 'test-pat'
            DesiredBranchList = @('refs/heads/main')
            Mode              = 'Replace'
        }
        $result = Get-GerberAdoSearchableBranchPolicyReport -Context $context

        $result.PSObject.Properties.Name | Should -Contain 'RepoList'
        $result.PSObject.Properties.Name | Should -Contain 'CreateList'
        $result.PSObject.Properties.Name | Should -Contain 'UpdateList'
        $result.PSObject.Properties.Name | Should -Contain 'AlreadyAlignedList'
    }

    It 'passes the policy map and repo list to scan and surfaces the scan categorization' {
        Mock Get-GerberAdoRepositoryList {
            @([pscustomobject]@{ Id = 'r1'; Name = 'Alpha' })
        }
        Mock Get-GerberAdoSearchableBranchPolicyMap { @{ 'r1' = [pscustomobject]@{ id = 10 } } }
        $createList = [System.Collections.Generic.List[pscustomobject]]::new()
        $null = $createList.Add([pscustomobject]@{ RepoId = 'r1'; RepoName = 'Alpha' })
        Mock Invoke-GerberSearchableBranchRepoScan {
            [pscustomobject]@{
                CreateList  = $createList
                UpdateList  = [System.Collections.Generic.List[pscustomobject]]::new()
                AlignedList = [System.Collections.Generic.List[pscustomobject]]::new()
            }
        }

        $context = [pscustomobject]@{
            Configuration     = [pscustomobject]@{ CredentialIdentifier = 'PAT' }
            Pat               = 'test-pat'
            DesiredBranchList = @('refs/heads/main')
            Mode              = 'Replace'
        }
        $result = Get-GerberAdoSearchableBranchPolicyReport -Context $context

        $result.RepoList.Count | Should -Be 1
        $result.CreateList.Count | Should -Be 1
        $result.CreateList[0].RepoName | Should -Be 'Alpha'
    }
}

Describe 'Get-GerberAdoSearchableBranchPolicyMap' {
    It 'builds a repositoryId-to-policy map from a matching policy list' {
        $policyTypeId = Get-GerberSearchableBranchPolicyTypeId
        $scope = @([pscustomobject]@{ repositoryId = 'repo-1' })
        Mock Invoke-GerberAdoRestRequest {
            [pscustomobject]@{
                value = @([pscustomobject]@{
                    id       = 42
                    type     = [pscustomobject]@{ id = $policyTypeId }
                    settings = [pscustomobject]@{
                        scope          = $scope
                        searchBranches = @('refs/heads/main')
                    }
                })
            }
        }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName            = 'MyProject'
                DefaultApiVersion      = '7.1'
                CredentialIdentifier = 'PAT'
                CollectionUri          = [uri]'https://ado.example.com/org/'
            }
            Pat = 'test-pat'
        }
        $result = Get-GerberAdoSearchableBranchPolicyMap -Context $context

        $result.Count | Should -Be 1
        $result['repo-1'] | Should -Not -BeNull
        $result['repo-1'].id | Should -Be 42
    }

    It 'returns an empty hashtable when the policy list is empty' {
        Mock Invoke-GerberAdoRestRequest { [pscustomobject]@{ value = @() } }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName            = 'MyProject'
                DefaultApiVersion      = '7.1'
                CredentialIdentifier = 'PAT'
                CollectionUri          = [uri]'https://ado.example.com/org/'
            }
            Pat = 'test-pat'
        }
        $result = Get-GerberAdoSearchableBranchPolicyMap -Context $context

        $result.Count | Should -Be 0
    }

    It 'filters out policies whose type ID does not match the searchable-branch type' {
        $policyTypeId = Get-GerberSearchableBranchPolicyTypeId
        Mock Invoke-GerberAdoRestRequest {
            [pscustomobject]@{
                value = @(
                    [pscustomobject]@{
                        id       = 1
                        type     = [pscustomobject]@{ id = 'other-type-id' }
                        settings = [pscustomobject]@{ scope = @([pscustomobject]@{ repositoryId = 'repo-x' }); searchBranches = @() }
                    },
                    [pscustomobject]@{
                        id       = 2
                        type     = [pscustomobject]@{ id = $policyTypeId }
                        settings = [pscustomobject]@{ scope = @([pscustomobject]@{ repositoryId = 'repo-y' }); searchBranches = @('refs/heads/main') }
                    }
                )
            }
        }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName            = 'P'
                DefaultApiVersion      = '7.1'
                CredentialIdentifier = 'PAT'
                CollectionUri          = [uri]'https://ado.example.com/org/'
            }
            Pat = 'test-pat'
        }
        $result = Get-GerberAdoSearchableBranchPolicyMap -Context $context

        $result.Count | Should -Be 1
        $result.ContainsKey('repo-x') | Should -BeFalse
        $result.ContainsKey('repo-y') | Should -BeTrue
    }
}

Describe 'Get-GerberSearchableBranchCurrentBranchList' {
    It 'returns the searchBranches strings from the policy when policy is not null' {
        $policy = [pscustomobject]@{
            settings = [pscustomobject]@{ searchBranches = @('refs/heads/main', 'refs/heads/develop') }
        }

        $result = Get-GerberSearchableBranchCurrentBranchList -Policy $policy

        @($result).Count | Should -Be 2
        $result | Should -Contain 'refs/heads/main'
        $result | Should -Contain 'refs/heads/develop'
    }

    It 'returns an empty array when policy is null' {
        $result = Get-GerberSearchableBranchCurrentBranchList -Policy $null

        @($result).Count | Should -Be 0
    }

    It 'returns an empty array when searchBranches is null' {
        $policy = [pscustomobject]@{
            settings = [pscustomobject]@{ searchBranches = $null }
        }

        $result = @(Get-GerberSearchableBranchCurrentBranchList -Policy $policy)

        $result.Count | Should -Be 0
    }

    It 'returns an empty array when settings is null' {
        $policy = [pscustomobject]@{ settings = $null }

        $result = @(Get-GerberSearchableBranchCurrentBranchList -Policy $policy)

        $result.Count | Should -Be 0
    }
}

Describe 'Get-GerberAdoSearchableBranchAllPoliciesUri' {
    It 'includes policyType and api-version in the query string' {
        $config = [pscustomobject]@{
            ProjectName       = 'MyProject'
            DefaultApiVersion = '7.1'
            CollectionUri     = [uri]'https://ado.example.com/org/'
        }
        $uri = Get-GerberAdoSearchableBranchAllPoliciesUri -Configuration $config

        $uri.AbsoluteUri | Should -BeLike '*policyType=0517f88d*'
        $uri.AbsoluteUri | Should -BeLike '*api-version=7.1*'
    }

    It 'includes the project name in the path' {
        $config = [pscustomobject]@{
            ProjectName       = 'MyProject'
            DefaultApiVersion = '7.1'
            CollectionUri     = [uri]'https://ado.example.com/org/'
        }
        $uri = Get-GerberAdoSearchableBranchAllPoliciesUri -Configuration $config

        $uri.AbsoluteUri | Should -BeLike '*MyProject/_apis/policy/configurations*'
    }

    It 'does not include a repositoryId in the query string' {
        $config = [pscustomobject]@{
            ProjectName       = 'P'
            DefaultApiVersion = '7.1'
            CollectionUri     = [uri]'https://ado.example.com/org/'
        }
        $uri = Get-GerberAdoSearchableBranchAllPoliciesUri -Configuration $config

        $uri.AbsoluteUri | Should -Not -BeLike '*repositoryId*'
    }
}

Describe 'Invoke-GerberSearchableBranchRepoScan' {
    It 'returns empty lists when repo list is empty' {
        Mock Write-GerberProgressBar {}

        $context = [pscustomobject]@{
            Configuration     = [pscustomobject]@{ CredentialIdentifier = 'PAT' }
            Pat               = 'test-pat'
            DesiredBranchList = @('refs/heads/main')
            Mode              = 'Replace'
        }
        $result = Invoke-GerberSearchableBranchRepoScan -Context $context -RepoList @() -PolicyMap @{}

        @($result.CreateList).Count | Should -Be 0
        @($result.UpdateList).Count | Should -Be 0
        @($result.AlignedList).Count | Should -Be 0
    }

    It 'routes items with NeedsChange=false to AlignedList' {
        Mock Write-GerberProgressBar {}
        Mock Get-GerberSearchableBranchPlanItem {
            [pscustomobject]@{ RepoId = 'r1'; RepoName = 'Alpha'; PolicyId = $null; NewScope = @(); NeedsChange = $false }
        }

        $context = [pscustomobject]@{
            Configuration     = [pscustomobject]@{ CredentialIdentifier = 'PAT' }
            Pat               = 'test-pat'
            DesiredBranchList = @('refs/heads/main')
            Mode              = 'Replace'
        }
        $result = Invoke-GerberSearchableBranchRepoScan `
            -Context $context `
            -RepoList @([pscustomobject]@{ Id = 'r1'; Name = 'Alpha' }) `
            -PolicyMap @{}

        @($result.AlignedList).Count | Should -Be 1
        @($result.CreateList).Count | Should -Be 0
        @($result.UpdateList).Count | Should -Be 0
    }

    It 'routes items with NeedsChange=true and no PolicyId to CreateList' {
        Mock Write-GerberProgressBar {}
        Mock Get-GerberSearchableBranchPlanItem {
            [pscustomobject]@{ RepoId = 'r1'; RepoName = 'Alpha'; PolicyId = $null; NewScope = @(); NeedsChange = $true }
        }

        $context = [pscustomobject]@{
            Configuration     = [pscustomobject]@{ CredentialIdentifier = 'PAT' }
            Pat               = 'test-pat'
            DesiredBranchList = @('refs/heads/main')
            Mode              = 'Replace'
        }
        $result = Invoke-GerberSearchableBranchRepoScan `
            -Context $context `
            -RepoList @([pscustomobject]@{ Id = 'r1'; Name = 'Alpha' }) `
            -PolicyMap @{}

        @($result.CreateList).Count | Should -Be 1
        @($result.UpdateList).Count | Should -Be 0
    }

    It 'routes items with NeedsChange=true and a PolicyId to UpdateList' {
        Mock Write-GerberProgressBar {}
        Mock Get-GerberSearchableBranchPlanItem {
            [pscustomobject]@{ RepoId = 'r1'; RepoName = 'Alpha'; PolicyId = '42'; NewScope = @(); NeedsChange = $true }
        }

        $context = [pscustomobject]@{
            Configuration     = [pscustomobject]@{ CredentialIdentifier = 'PAT' }
            Pat               = 'test-pat'
            DesiredBranchList = @('refs/heads/main')
            Mode              = 'Replace'
        }
        $result = Invoke-GerberSearchableBranchRepoScan `
            -Context $context `
            -RepoList @([pscustomobject]@{ Id = 'r1'; Name = 'Alpha' }) `
            -PolicyMap @{}

        @($result.UpdateList).Count | Should -Be 1
        @($result.CreateList).Count | Should -Be 0
    }
}

Describe 'Get-GerberSearchableBranchPlanItem' {
    It 'returns NeedsChange=true and PolicyId=null when repo is not in the policy map' {
        Mock Build-GerberSearchableBranchNewScope { @('refs/heads/main') }
        Mock Test-GerberSearchableBranchScopeAligned { $false }

        $context = [pscustomobject]@{
            DesiredBranchList = @('refs/heads/main')
            Mode              = 'Replace'
        }
        $repo = [pscustomobject]@{ Id = 'r1'; Name = 'Alpha' }
        $result = Get-GerberSearchableBranchPlanItem -Context $context -Repo $repo -PolicyMap @{}

        $result.NeedsChange | Should -BeTrue
        $result.PolicyId | Should -BeNull
    }

    It 'returns NeedsChange=false and PolicyId set when map has policy with aligned branches' {
        $policy = [pscustomobject]@{
            id       = 99
            settings = [pscustomobject]@{ searchBranches = @('refs/heads/main') }
        }
        Mock Build-GerberSearchableBranchNewScope { @('refs/heads/main') }
        Mock Test-GerberSearchableBranchScopeAligned { $true }

        $context = [pscustomobject]@{
            DesiredBranchList = @('refs/heads/main')
            Mode              = 'Replace'
        }
        $repo = [pscustomobject]@{ Id = 'r1'; Name = 'Alpha' }
        $result = Get-GerberSearchableBranchPlanItem -Context $context -Repo $repo -PolicyMap @{ 'r1' = $policy }

        $result.NeedsChange | Should -BeFalse
        $result.PolicyId | Should -Be '99'
    }

    It 'returns NeedsChange=true and PolicyId set when map has policy but branches differ' {
        $policy = [pscustomobject]@{
            id       = 55
            settings = [pscustomobject]@{ searchBranches = @('refs/heads/old') }
        }
        Mock Build-GerberSearchableBranchNewScope { @('refs/heads/main') }
        Mock Test-GerberSearchableBranchScopeAligned { $false }

        $context = [pscustomobject]@{
            DesiredBranchList = @('refs/heads/main')
            Mode              = 'Replace'
        }
        $repo = [pscustomobject]@{ Id = 'r1'; Name = 'Alpha' }
        $result = Get-GerberSearchableBranchPlanItem -Context $context -Repo $repo -PolicyMap @{ 'r1' = $policy }

        $result.NeedsChange | Should -BeTrue
        $result.PolicyId | Should -Be '55'
    }

    It 'returns NewScope as an array even when only one branch is in scope' {
        $context = [pscustomobject]@{
            DesiredBranchList = @('refs/heads/develop')
            Mode              = 'Merge'
        }
        $repo = [pscustomobject]@{ Id = 'r1'; Name = 'Alpha'; DefaultBranch = '' }

        $result = Get-GerberSearchableBranchPlanItem -Context $context -Repo $repo -PolicyMap @{}

        @($result.NewScope).Count | Should -Be 1
        $result.NewScope | Should -Contain 'refs/heads/develop'
    }

    It 'returns NeedsChange=false and empty NewScope when desired branch is the repo default branch and no policy exists' {
        $context = [pscustomobject]@{
            DesiredBranchList = @('refs/heads/develop')
            Mode              = 'Merge'
        }
        $repo = [pscustomobject]@{ Id = 'r1'; Name = 'Alpha'; DefaultBranch = 'refs/heads/develop' }

        $result = Get-GerberSearchableBranchPlanItem -Context $context -Repo $repo -PolicyMap @{}

        $result.NeedsChange | Should -BeFalse
        @($result.NewScope).Count | Should -Be 0
    }
}

Describe 'Build-GerberSearchableBranchNewScope' {
    It 'returns only the desired branch strings in Replace mode' {
        $result = Build-GerberSearchableBranchNewScope `
            -DesiredBranchList @('refs/heads/main', 'refs/heads/dev') `
            -CurrentBranches @('refs/heads/old') `
            -Mode 'Replace'

        @($result).Count | Should -Be 2
        $result | Should -Contain 'refs/heads/main'
        $result | Should -Contain 'refs/heads/dev'
        $result | Should -Not -Contain 'refs/heads/old'
    }

    It 'returns the union of desired and existing branches in Merge mode deduplicated' {
        $result = Build-GerberSearchableBranchNewScope `
            -DesiredBranchList @('refs/heads/main', 'refs/heads/dev') `
            -CurrentBranches @('refs/heads/main', 'refs/heads/release') `
            -Mode 'Merge'

        @($result).Count | Should -Be 3
        $result | Should -Contain 'refs/heads/main'
        $result | Should -Contain 'refs/heads/dev'
        $result | Should -Contain 'refs/heads/release'
    }

    It 'deduplicates case-insensitively in Merge mode' {
        $result = Build-GerberSearchableBranchNewScope `
            -DesiredBranchList @('refs/heads/main') `
            -CurrentBranches @('refs/heads/Main') `
            -Mode 'Merge'

        @($result).Count | Should -Be 1
    }

    It 'returns an empty array when DesiredBranchList is empty in Replace mode' {
        $result = Build-GerberSearchableBranchNewScope `
            -DesiredBranchList @() `
            -CurrentBranches @() `
            -Mode 'Replace'

        @($result).Count | Should -Be 0
    }

    It 'strips the default branch from the scope in Replace mode' {
        $result = Build-GerberSearchableBranchNewScope `
            -DesiredBranchList @('refs/heads/develop', 'refs/heads/main') `
            -CurrentBranches @() `
            -Mode 'Replace' `
            -DefaultBranch 'refs/heads/develop'

        @($result).Count | Should -Be 1
        $result | Should -Contain 'refs/heads/main'
        $result | Should -Not -Contain 'refs/heads/develop'
    }

    It 'strips the default branch from the merged scope in Merge mode' {
        $result = Build-GerberSearchableBranchNewScope `
            -DesiredBranchList @('refs/heads/develop', 'refs/heads/main') `
            -CurrentBranches @('refs/heads/release') `
            -Mode 'Merge' `
            -DefaultBranch 'refs/heads/develop'

        $result | Should -Contain 'refs/heads/main'
        $result | Should -Contain 'refs/heads/release'
        $result | Should -Not -Contain 'refs/heads/develop'
    }

    It 'returns an empty array when the only desired branch equals the default branch' {
        $result = Build-GerberSearchableBranchNewScope `
            -DesiredBranchList @('refs/heads/develop') `
            -CurrentBranches @() `
            -Mode 'Replace' `
            -DefaultBranch 'refs/heads/develop'

        @($result).Count | Should -Be 0
    }
}

Describe 'Get-GerberExplicitBranchScope' {
    It 'returns scope unchanged when DefaultBranch is empty' {
        $result = Get-GerberExplicitBranchScope `
            -Scope @('refs/heads/main', 'refs/heads/develop') `
            -DefaultBranch ''

        @($result).Count | Should -Be 2
    }

    It 'removes the default branch case-insensitively' {
        $result = Get-GerberExplicitBranchScope `
            -Scope @('refs/heads/Main', 'refs/heads/develop') `
            -DefaultBranch 'refs/heads/main'

        @($result).Count | Should -Be 1
        $result | Should -Contain 'refs/heads/develop'
        $result | Should -Not -Contain 'refs/heads/Main'
    }

    It 'returns an empty array when the scope contains only the default branch' {
        $result = Get-GerberExplicitBranchScope `
            -Scope @('refs/heads/develop') `
            -DefaultBranch 'refs/heads/develop'

        @($result).Count | Should -Be 0
    }
}

Describe 'Test-GerberSearchableBranchScopeAligned' {
    It 'returns true when both string arrays contain the same branches regardless of order' {
        $result = Test-GerberSearchableBranchScopeAligned `
            -NewScope @('refs/heads/main', 'refs/heads/dev') `
            -CurrentScope @('refs/heads/dev', 'refs/heads/main')

        $result | Should -BeTrue
    }

    It 'returns false when counts differ' {
        $result = Test-GerberSearchableBranchScopeAligned `
            -NewScope @('refs/heads/main', 'refs/heads/dev') `
            -CurrentScope @('refs/heads/main')

        $result | Should -BeFalse
    }

    It 'returns false when a branch in NewScope is missing from CurrentScope' {
        $result = Test-GerberSearchableBranchScopeAligned `
            -NewScope @('refs/heads/feature') `
            -CurrentScope @('refs/heads/main')

        $result | Should -BeFalse
    }

    It 'returns true for two empty arrays' {
        $result = Test-GerberSearchableBranchScopeAligned -NewScope @() -CurrentScope @()

        $result | Should -BeTrue
    }

    It 'compares branch strings case-insensitively' {
        $result = Test-GerberSearchableBranchScopeAligned `
            -NewScope @('refs/heads/Main') `
            -CurrentScope @('refs/heads/main')

        $result | Should -BeTrue
    }
}

Describe 'Add-GerberSearchableBranchPlanItem' {
    It 'adds to AlignedList when NeedsChange is false' {
        $lists = [pscustomobject]@{
            CreateList  = [System.Collections.Generic.List[pscustomobject]]::new()
            UpdateList  = [System.Collections.Generic.List[pscustomobject]]::new()
            AlignedList = [System.Collections.Generic.List[pscustomobject]]::new()
        }
        $item = [pscustomobject]@{ RepoName = 'Alpha'; PolicyId = $null; NeedsChange = $false }

        Add-GerberSearchableBranchPlanItem -Item $item -Lists $lists

        $lists.AlignedList.Count | Should -Be 1
        $lists.CreateList.Count | Should -Be 0
        $lists.UpdateList.Count | Should -Be 0
    }

    It 'adds to CreateList when NeedsChange is true and PolicyId is null' {
        $lists = [pscustomobject]@{
            CreateList  = [System.Collections.Generic.List[pscustomobject]]::new()
            UpdateList  = [System.Collections.Generic.List[pscustomobject]]::new()
            AlignedList = [System.Collections.Generic.List[pscustomobject]]::new()
        }
        $item = [pscustomobject]@{ RepoName = 'Beta'; PolicyId = $null; NeedsChange = $true }

        Add-GerberSearchableBranchPlanItem -Item $item -Lists $lists

        $lists.CreateList.Count | Should -Be 1
        $lists.UpdateList.Count | Should -Be 0
    }

    It 'adds to UpdateList when NeedsChange is true and PolicyId is non-null' {
        $lists = [pscustomobject]@{
            CreateList  = [System.Collections.Generic.List[pscustomobject]]::new()
            UpdateList  = [System.Collections.Generic.List[pscustomobject]]::new()
            AlignedList = [System.Collections.Generic.List[pscustomobject]]::new()
        }
        $item = [pscustomobject]@{ RepoName = 'Gamma'; PolicyId = '77'; NeedsChange = $true }

        Add-GerberSearchableBranchPlanItem -Item $item -Lists $lists

        $lists.UpdateList.Count | Should -Be 1
        $lists.CreateList.Count | Should -Be 0
    }
}
