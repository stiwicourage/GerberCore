BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoRepositoryItemTree' {
    BeforeEach {
        $script:capturedQuery = $null
        Mock Get-GerberAdoApiUri {
            $script:capturedQuery = $QueryParameterMap
            [uri]'https://example.test/api'
        }
        $script:context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'TestProj'
                CollectionUri = [uri]'https://example.test/'
                DefaultApiVersion = '7.0'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
        }
    }

    It 'returns success with file tree when request succeeds' {
        Mock Get-GerberAdoApiUri { [uri]'https://example.test/api' }
        Mock Get-GerberAdoRequestHeader { @{ Authorization = 'Basic dGVzdA==' } }
        Mock Invoke-GerberAdoRestRequest {
            @{
                value = @(
                    @{ path = '/file1.txt'; gitObjectType = 'blob' }
                    @{ path = '/folder'; gitObjectType = 'tree' }
                )
            }
        }
        Mock Invoke-WebRequest {
            [pscustomobject]@{ Content = 'file content here' }
        }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'TestProj'
                CollectionUri = [uri]'https://example.test/'
                DefaultApiVersion = '7.0'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
        }
        $result = Get-GerberAdoRepositoryItemTree -Context $context -RepoId 'r1'

        $result.Success | Should -BeTrue
        $result.FileTree.Count | Should -Be 1
        $result.FileTree[0].path | Should -Be '/file1.txt'
        $result.FileTree[0].content | Should -Be 'file content here'
    }

    It 'returns string content for XML files such as .csproj' {
        Mock Get-GerberAdoApiUri { [uri]'https://example.test/api' }
        Mock Get-GerberAdoRequestHeader { @{ Authorization = 'Basic dGVzdA==' } }
        Mock Invoke-GerberAdoRestRequest {
            @{
                value = @(
                    @{ path = '/PackageName/PackageName.csproj'; gitObjectType = 'blob' }
                )
            }
        }
        Mock Invoke-WebRequest {
            [pscustomobject]@{ Content = '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup></PropertyGroup></Project>' }
        }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'TestProj'
                CollectionUri = [uri]'https://example.test/'
                DefaultApiVersion = '7.0'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
        }
        $result = Get-GerberAdoRepositoryItemTree -Context $context -RepoId 'r1'

        $result.Success | Should -BeTrue
        $result.FileTree[0].content | Should -BeOfType [string]
        $result.FileTree[0].content | Should -BeLike '*Project*'
    }

    It 'decodes byte array content as UTF-8 string' {
        Mock Get-GerberAdoApiUri { [uri]'https://example.test/api' }
        Mock Get-GerberAdoRequestHeader { @{ Authorization = 'Basic dGVzdA==' } }
        Mock Invoke-GerberAdoRestRequest {
            @{
                value = @(
                    @{ path = '/README.md'; gitObjectType = 'blob' }
                )
            }
        }
        Mock Invoke-WebRequest {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes('# Hello æøå')
            [pscustomobject]@{ Content = $bytes }
        }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'TestProj'
                CollectionUri = [uri]'https://example.test/'
                DefaultApiVersion = '7.0'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
        }
        $result = Get-GerberAdoRepositoryItemTree -Context $context -RepoId 'r1'

        $result.Success | Should -BeTrue
        $result.FileTree[0].content | Should -Be '# Hello æøå'
    }

    It 'returns failure when request throws exception' {
        Mock Get-GerberAdoApiUri { [uri]'https://example.test/api' }
        Mock Invoke-GerberAdoRestRequest { throw [System.InvalidOperationException]::new('API error') }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'TestProj'
                CollectionUri = [uri]'https://example.test/'
                DefaultApiVersion = '7.0'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
        }
        $result = Get-GerberAdoRepositoryItemTree -Context $context -RepoId 'r1'

        $result.Success | Should -BeFalse
        $result.FileTree.Count | Should -Be 0
    }

    It 'includes versionDescriptor query params in the item-list URI when BranchName is provided' {
        Mock Get-GerberAdoRequestHeader { @{ Authorization = 'Basic dGVzdA==' } }
        Mock Invoke-GerberAdoRestRequest { @{ value = @() } }

        $null = Get-GerberAdoRepositoryItemTree -Context $context -RepoId 'r1' -BranchName 'develop'

        $script:capturedQuery['versionDescriptor.version']     | Should -Be 'develop'
        $script:capturedQuery['versionDescriptor.versionType'] | Should -Be 'branch'
    }

    It 'omits versionDescriptor query params from the item-list URI when BranchName is not provided' {
        Mock Get-GerberAdoRequestHeader { @{ Authorization = 'Basic dGVzdA==' } }
        Mock Invoke-GerberAdoRestRequest { @{ value = @() } }

        $null = Get-GerberAdoRepositoryItemTree -Context $context -RepoId 'r1'

        $script:capturedQuery.ContainsKey('versionDescriptor.version')     | Should -BeFalse
        $script:capturedQuery.ContainsKey('versionDescriptor.versionType') | Should -BeFalse
    }

    It 'uses the selected project scope for template file retrieval when configuration points elsewhere' {
        $script:capturedBaseUri = $null
        Mock Get-GerberAdoApiUri {
            $script:capturedBaseUri = $BaseUri.AbsoluteUri
            [uri]'https://example.test/api'
        }
        Mock Get-GerberAdoRequestHeader { @{ Authorization = 'Basic dGVzdA==' } }
        Mock Invoke-GerberAdoRestRequest { @{ value = @() } }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'Project-A'
                CollectionUri = [uri]'https://example.test/'
                DefaultApiVersion = '7.0'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
            Project = [pscustomobject]@{ Id = 'project-b-id'; Name = 'Project-B' }
        }
        $null = Get-GerberAdoRepositoryItemTree -Context $context -RepoId 'r1'

        $script:capturedBaseUri | Should -Be 'https://example.test/project-b-id/_apis/git/repositories/r1/items'
    }
}
