BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'New-GerberAdoRepositoryInitialCommit' {
    BeforeEach {
        $script:context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'TestProj'
                CollectionUri = [uri]'https://example.test/'
                DefaultApiVersion = '7.0'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
            RepositoryName = 'TestPkg'
        }
    }

    It 'returns success when commit creation succeeds' {
        Mock Get-GerberAdoCommitChangeList { @(@{ changeType = 'add' }) }
        Mock Get-GerberAdoApiUri { [uri]'https://example.test/api' }
        Mock ConvertTo-Json { '{"commits":[]}' }
        Mock Invoke-RestMethod { @{ pushId = 12345 } }

        $result = New-GerberAdoRepositoryInitialCommit -Context $context -RepoId 'r1' -FileTree @() -DefaultBranchRef 'refs/heads/develop'

        $result.Success | Should -BeTrue
    }

    It 'returns failure when commit creation throws exception' {
        Mock Get-GerberAdoCommitChangeList { throw [System.InvalidOperationException]::new('Error') }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'TestProj'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
            RepositoryName = 'TestPkg'
        }
        $result = New-GerberAdoRepositoryInitialCommit -Context $context -RepoId 'r1' -FileTree @() -DefaultBranchRef 'refs/heads/develop'

        $result.Success | Should -BeFalse
    }

    It 'returns failure with descriptive message when Get-GerberAdoCommitChangeList returns empty' {
        Mock Get-GerberAdoCommitChangeList { @() }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'TestProj'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
            RepositoryName = 'TestPkg'
        }
        $result = New-GerberAdoRepositoryInitialCommit -Context $context -RepoId 'r1' -FileTree @() -DefaultBranchRef 'refs/heads/develop'

        $result.Success | Should -BeFalse
        $result.ErrorDetail | Should -BeLike '*No files to commit*'
    }

    It 'uses DefaultBranchRef in the push body refUpdates name' {
        $script:capturedBody = $null
        Mock Get-GerberAdoCommitChangeList { @(@{ changeType = 'add' }) }
        Mock Get-GerberAdoApiUri { [uri]'https://example.test/api' }
        Mock ConvertTo-Json {
            $script:capturedBody = $InputObject
            '{"refUpdates":[]}'
        }
        Mock Invoke-RestMethod { @{ pushId = 1 } }

        $null = New-GerberAdoRepositoryInitialCommit -Context $context -RepoId 'r1' -FileTree @() -DefaultBranchRef 'refs/heads/develop'

        $script:capturedBody.refUpdates[0].name | Should -Be 'refs/heads/develop'
    }

    It 'uses the selected project scope for the initial-commit request when configuration points elsewhere' {
        $script:capturedBaseUri = $null
        Mock Get-GerberAdoCommitChangeList { @(@{ changeType = 'add' }) }
        Mock Get-GerberAdoApiUri {
            $script:capturedBaseUri = $BaseUri.AbsoluteUri
            [uri]'https://example.test/api'
        }
        Mock ConvertTo-Json { '{"refUpdates":[]}' }
        Mock Invoke-RestMethod { @{ pushId = 1 } }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'Project-A'
                CollectionUri = [uri]'https://example.test/'
                DefaultApiVersion = '7.0'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
            RepositoryName = 'TestPkg'
            Project = [pscustomobject]@{ Id = 'project-b-id'; Name = 'Project-B' }
        }
        $null = New-GerberAdoRepositoryInitialCommit -Context $context -RepoId 'r1' -FileTree @() -DefaultBranchRef 'refs/heads/develop'

        $script:capturedBaseUri | Should -Be 'https://example.test/project-b-id/_apis/git/repositories/r1/pushes'
    }
}

Describe 'Get-GerberAdoCommitChangeList' {
    It 'creates add changes for blob items and replaces legacy PackageName placeholders with RepositoryName' {
        $fileTree = @(
            @{ gitObjectType = 'blob'; path = '/PackageName/file.txt'; content = 'Hello PackageName' }
            @{ gitObjectType = 'tree'; path = '/folder' }
        )

        $result = @(Get-GerberAdoCommitChangeList -FileTree $fileTree -RepositoryName 'MyPkg')

        $result.Count | Should -Be 1
        $result[0].changeType | Should -Be 'add'
        $result[0].item.path | Should -Be '/MyPkg/file.txt'
        $result[0].newContent.content | Should -Be 'Hello MyPkg'
    }

    It 'returns empty array when no blob items exist' {
        $fileTree = @(
            @{ gitObjectType = 'tree'; path = '/folder' }
        )

        $result = Get-GerberAdoCommitChangeList -FileTree $fileTree -RepositoryName 'MyPkg'

        $result.Count | Should -Be 0
    }
}

Describe 'Resolve-GerberLegacyPackageNamePlaceholder' {
    It 'replaces the legacy PackageName placeholder with RepositoryName' {
        $result = Resolve-GerberLegacyPackageNamePlaceholder -Text '/PackageName/file.txt' -RepositoryName 'MyPkg'

        $result | Should -Be '/MyPkg/file.txt'
    }

    It 'returns unchanged path when PackageName is not present' {
        $result = Resolve-GerberLegacyPackageNamePlaceholder -Text '/other/file.txt' -RepositoryName 'MyPkg'

        $result | Should -Be '/other/file.txt'
    }
}
