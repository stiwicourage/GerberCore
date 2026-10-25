BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoBranchSearchResult' {
    It 'returns a result with Total, FoundList, FailedList, and NormalizedBranchPath' {
        Mock Get-GerberAdoRepositoryList { @() }
        Mock Invoke-GerberAdoBranchRepositoryScan {
            [pscustomobject]@{ FoundList = @(); FailedList = @() }
        }

        $result = Get-GerberAdoBranchSearchResult `
            -Configuration ([pscustomobject]@{ ProjectName = 'MyProject'; DefaultApiVersion = '7.1'; CredentialIdentifier = 'PAT' }) `
            -Pat 'test-pat' `
            -NormalizedBranchPath 'refs/heads/item/juni2026'

        $result.NormalizedBranchPath | Should -Be 'refs/heads/item/juni2026'
        $result.Total | Should -Be 0
        $result.PSObject.Properties.Name | Should -Contain 'FoundList'
        $result.PSObject.Properties.Name | Should -Contain 'FailedList'
    }

    It 'passes repo list length as Total when repos are returned' {
        Mock Get-GerberAdoRepositoryList {
            @(
                [pscustomobject]@{ Id = 'r1'; Name = 'Repo1' }
                [pscustomobject]@{ Id = 'r2'; Name = 'Repo2' }
            )
        }
        Mock Invoke-GerberAdoBranchRepositoryScan {
            [pscustomobject]@{ FoundList = @('Repo1'); FailedList = @() }
        }

        $result = Get-GerberAdoBranchSearchResult `
            -Configuration ([pscustomobject]@{ ProjectName = 'P'; DefaultApiVersion = '7.1'; CredentialIdentifier = 'PAT' }) `
            -Pat 'test-pat' `
            -NormalizedBranchPath 'refs/heads/main'

        $result.Total | Should -Be 2
        $result.FoundList | Should -Be @('Repo1')
    }
}

Describe 'Invoke-GerberAdoBranchRepositoryScan' {
    It 'returns empty found and failed lists when repo list is empty' {
        Mock Write-GerberProgressBar {}

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{ DefaultApiVersion = '7.1'; CredentialIdentifier = 'PAT' }
            Pat = 'test-pat'
            BranchPath = 'refs/heads/main'
        }
        $result = Invoke-GerberAdoBranchRepositoryScan -Context $context -RepoList @()

        @($result.FoundList).Count | Should -Be 0
        @($result.FailedList).Count | Should -Be 0
    }

    It 'adds repo to FoundList when branch exists' {
        Mock Write-GerberProgressBar {}
        Mock Test-GerberAdoRepoBranchPresence { $true }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'P'
                DefaultApiVersion = '7.1'
                CredentialIdentifier = 'PAT'
                CollectionUri = [uri]'https://ado.example.com/org/'
            }
            Pat = 'test-pat'
            BranchPath = 'refs/heads/feature/x'
        }
        $result = Invoke-GerberAdoBranchRepositoryScan `
            -Context $context `
            -RepoList @([pscustomobject]@{ Id = 'r1'; Name = 'Alpha' })

        $result.FoundList | Should -Contain 'Alpha'
        @($result.FailedList).Count | Should -Be 0
    }

    It 'adds repo to FailedList when per-repo check throws' {
        Mock Write-GerberProgressBar {}
        Mock Test-GerberAdoRepoBranchPresence { throw [System.Exception]::new('Network error') }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'P'
                DefaultApiVersion = '7.1'
                CredentialIdentifier = 'PAT'
                CollectionUri = [uri]'https://ado.example.com/org/'
            }
            Pat = 'test-pat'
            BranchPath = 'refs/heads/feature/x'
        }
        $result = Invoke-GerberAdoBranchRepositoryScan `
            -Context $context `
            -RepoList @([pscustomobject]@{ Id = 'r1'; Name = 'Beta' })

        @($result.FoundList).Count | Should -Be 0
        $result.FailedList | Should -Contain 'Beta'
    }

    It 'continues scanning after a per-repo failure' {
        Mock Write-GerberProgressBar {}
        $script:branchScanCallIndex = 0
        Mock Test-GerberAdoRepoBranchPresence {
            $script:branchScanCallIndex++
            if ($script:branchScanCallIndex -eq 1) { throw [System.Exception]::new('Fail') }
            return $true
        }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'P'
                DefaultApiVersion = '7.1'
                CredentialIdentifier = 'PAT'
                CollectionUri = [uri]'https://ado.example.com/org/'
            }
            Pat = 'test-pat'
            BranchPath = 'refs/heads/feature/x'
        }
        $result = Invoke-GerberAdoBranchRepositoryScan `
            -Context $context `
            -RepoList @(
                [pscustomobject]@{ Id = 'r1'; Name = 'Broken' }
                [pscustomobject]@{ Id = 'r2'; Name = 'Working' }
            )

        $result.FailedList | Should -Contain 'Broken'
        $result.FoundList | Should -Contain 'Working'
    }

    It 'calls Write-GerberProgressBar once per scanned repository' {
        Mock Write-GerberProgressBar {}
        Mock Test-GerberAdoRepoBranchPresence { $false }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'P'
                DefaultApiVersion = '7.1'
                CredentialIdentifier = 'PAT'
                CollectionUri = [uri]'https://ado.example.com/org/'
            }
            Pat = 'test-pat'
            BranchPath = 'refs/heads/x'
        }
        Invoke-GerberAdoBranchRepositoryScan `
            -Context $context `
            -RepoList @(
                [pscustomobject]@{ Id = 'r1'; Name = 'A' }
                [pscustomobject]@{ Id = 'r2'; Name = 'B' }
            )

        Should -Invoke Write-GerberProgressBar -Times 1 -ParameterFilter { $Current -eq 1 -and $Total -eq 2 }
        Should -Invoke Write-GerberProgressBar -Times 1 -ParameterFilter { $Current -eq 2 -and $Total -eq 2 }
    }
}

Describe 'Test-GerberAdoRepoBranchPresence' {
    It 'returns true when refs endpoint returns non-empty value list' {
        Mock Invoke-GerberAdoRestRequest {
            [pscustomobject]@{ value = @([pscustomobject]@{ name = 'refs/heads/feature/x' }) }
        }

        $config = [pscustomobject]@{
            ProjectName = 'MyProject'
            DefaultApiVersion = '7.1'
            CredentialIdentifier = 'PAT'
            CollectionUri = [uri]'https://ado.example.com/org/'
        }
        $result = Test-GerberAdoRepoBranchPresence `
            -Configuration $config `
            -Pat 'test-pat' `
            -RepoId 'repo-1' `
            -BranchPath 'refs/heads/feature/x'

        $result | Should -BeTrue
    }

    It 'returns false when refs endpoint returns an empty value list' {
        Mock Invoke-GerberAdoRestRequest {
            [pscustomobject]@{ value = @() }
        }

        $config = [pscustomobject]@{
            ProjectName = 'MyProject'
            DefaultApiVersion = '7.1'
            CredentialIdentifier = 'PAT'
            CollectionUri = [uri]'https://ado.example.com/org/'
        }
        $result = Test-GerberAdoRepoBranchPresence `
            -Configuration $config `
            -Pat 'test-pat' `
            -RepoId 'repo-1' `
            -BranchPath 'refs/heads/nonexistent'

        $result | Should -BeFalse
    }

    It 'builds the refs URI with the project name, repo id, and filter stripped of refs/ prefix' {
        Mock Invoke-GerberAdoRestRequest { [pscustomobject]@{ value = @() } }

        $config = [pscustomobject]@{
            ProjectName = 'MyProject'
            DefaultApiVersion = '7.1'
            CredentialIdentifier = 'PAT'
            CollectionUri = [uri]'https://ado.example.com/org/'
        }
        Test-GerberAdoRepoBranchPresence `
            -Configuration $config `
            -Pat 'test-pat' `
            -RepoId 'repo-abc' `
            -BranchPath 'refs/heads/feature/x' | Out-Null

        Should -Invoke Invoke-GerberAdoRestRequest -Times 1 -ParameterFilter {
            $Uri.AbsoluteUri -like '*MyProject/_apis/git/repositories/repo-abc/refs*' -and
            $Uri.AbsoluteUri -like '*api-version=7.1*' -and
            $Uri.AbsoluteUri -like '*filter=*' -and
            $Uri.AbsoluteUri -notlike '*filter=refs*'
        }
    }
}

Describe 'Get-GerberAdoRepositoryList' {
    It 'returns mapped repository objects from the ADO response' {
        Mock Invoke-GerberAdoRestRequest {
            [pscustomobject]@{
                value = @(
                    [pscustomobject]@{ id = 'repo-1'; name = 'Alpha'; defaultBranch = 'refs/heads/main' }
                    [pscustomobject]@{ id = 'repo-2'; name = 'Beta'; defaultBranch = 'refs/heads/develop' }
                )
            }
        }

        $config = [pscustomobject]@{
            ProjectName = 'MyProject'
            DefaultApiVersion = '7.1'
            CredentialIdentifier = 'PAT'
            CollectionUri = [uri]'https://ado.example.com/org/'
        }
        $result = Get-GerberAdoRepositoryList -Configuration $config -Pat 'test-pat'

        $result.Count | Should -Be 2
        $result[0].Id | Should -Be 'repo-1'
        $result[0].Name | Should -Be 'Alpha'
        $result[0].DefaultBranch | Should -Be 'refs/heads/main'
        $result[1].DefaultBranch | Should -Be 'refs/heads/develop'
    }

    It 'builds the repositories URI with the project name and api-version' {
        Mock Invoke-GerberAdoRestRequest { [pscustomobject]@{ value = @() } }

        $config = [pscustomobject]@{
            ProjectName = 'MyProject'
            DefaultApiVersion = '7.1'
            CredentialIdentifier = 'PAT'
            CollectionUri = [uri]'https://ado.example.com/org/'
        }
        Get-GerberAdoRepositoryList -Configuration $config -Pat 'test-pat'

        Should -Invoke Invoke-GerberAdoRestRequest -Times 1 -ParameterFilter {
            $Uri.AbsoluteUri -like '*MyProject/_apis/git/repositories*' -and
            $Uri.AbsoluteUri -like '*api-version=7.1*'
        }
    }

    It 'excludes disabled repositories from the returned list' {
        Mock Invoke-GerberAdoRestRequest {
            [pscustomobject]@{
                value = @(
                    [pscustomobject]@{ id = 'repo-1'; name = 'Active'; defaultBranch = 'refs/heads/main'; isDisabled = $false }
                    [pscustomobject]@{ id = 'repo-2'; name = 'Archived'; defaultBranch = 'refs/heads/main'; isDisabled = $true }
                )
            }
        }

        $config = [pscustomobject]@{
            ProjectName = 'P'
            DefaultApiVersion = '7.1'
            CredentialIdentifier = 'PAT'
            CollectionUri = [uri]'https://ado.example.com/org/'
        }
        $result = Get-GerberAdoRepositoryList -Configuration $config -Pat 'test-pat'

        @($result).Count | Should -Be 1
        $result[0].Name | Should -Be 'Active'
    }

    It 'returns an empty array when the project has no repositories' {
        Mock Invoke-GerberAdoRestRequest { [pscustomobject]@{ value = @() } }

        $config = [pscustomobject]@{
            ProjectName = 'Empty'
            DefaultApiVersion = '7.1'
            CredentialIdentifier = 'PAT'
            CollectionUri = [uri]'https://ado.example.com/org/'
        }
        $result = Get-GerberAdoRepositoryList -Configuration $config -Pat 'test-pat'

        @($result).Count | Should -Be 0
    }
}

Describe 'Get-GerberAdoBranchRequestUri' {
    It 'includes api-version in the query string' {
        $config = [pscustomobject]@{
            DefaultApiVersion = '7.1'
            CollectionUri = [uri]'https://ado.example.com/org/'
        }
        $uri = Get-GerberAdoBranchRequestUri -Configuration $config -RelativePath 'P/_apis/git/repositories'

        $uri.AbsoluteUri | Should -BeLike '*api-version=7.1*'
    }

    It 'adds filter to query string when Filter is provided' {
        $config = [pscustomobject]@{
            DefaultApiVersion = '7.1'
            CollectionUri = [uri]'https://ado.example.com/org/'
        }
        $uri = Get-GerberAdoBranchRequestUri `
            -Configuration $config `
            -RelativePath 'P/_apis/git/repositories/r1/refs' `
            -Filter 'refs/heads/feature/x'

        $uri.AbsoluteUri | Should -BeLike '*filter=*'
    }

    It 'omits filter from query string when Filter is empty' {
        $config = [pscustomobject]@{
            DefaultApiVersion = '7.1'
            CollectionUri = [uri]'https://ado.example.com/org/'
        }
        $uri = Get-GerberAdoBranchRequestUri -Configuration $config -RelativePath 'P/_apis/git/repositories'

        $uri.AbsoluteUri | Should -Not -BeLike '*filter=*'
    }
}

Describe 'Get-GerberAdoBranchRefFilterValue' {
    It 'strips refs/ prefix from a normalized branch path' {
        $result = Get-GerberAdoBranchRefFilterValue -NormalizedBranchPath 'refs/heads/item/december2026'
        $result | Should -Be 'heads/item/december2026'
    }

    It 'returns the path unchanged when it does not start with refs/' {
        $result = Get-GerberAdoBranchRefFilterValue -NormalizedBranchPath 'heads/feature/x'
        $result | Should -Be 'heads/feature/x'
    }

    It 'strips refs/ prefix case-insensitively' {
        $result = Get-GerberAdoBranchRefFilterValue -NormalizedBranchPath 'REFS/heads/main'
        $result | Should -Be 'heads/main'
    }
}
