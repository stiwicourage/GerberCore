BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot

    function Get-ChangedFileContext {
        [CmdletBinding()]
        param()

        return [pscustomobject]@{
            Pat = 'pat'
            Configuration = [pscustomobject]@{
                CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                DefaultApiVersion = '7.0'
                CredentialIdentifier = 'gerber:ado:example:pat'
            }
        }
    }

    function Get-ChangedFilePullRequest {
        [CmdletBinding()]
        param()

        return [pscustomobject]@{
            PullRequestId = 18075
            ProjectName = 'ExampleProject'
            RepositoryId = 'repo-id'
        }
    }
}

Describe 'Get-GerberAdoPullRequestChangedFileList' {
    It 'returns changed file paths and change types from the latest iteration' {
        Mock Get-GerberAdoPullRequestLatestIterationId { 7 }
        Mock Get-GerberAdoPullRequestChangeUri { [uri]'https://ado.example.test/test' }
        Mock Invoke-GerberAdoRestRequest {
            [pscustomobject]@{
                changeEntries = @(
                    [pscustomobject]@{
                        item = [pscustomobject]@{ path = '/appsettings.U1.json' }
                        changeType = 'edit'
                    }
                )
            }
        }

        $result = Get-GerberAdoPullRequestChangedFileList `
            -Context ([pscustomobject]@{ Pat = 'pat'; Configuration = [pscustomobject]@{ CredentialIdentifier = 'gerber:ado:example:pat' } }) `
            -PullRequest ([pscustomobject]@{ PullRequestId = 18075; ProjectName = 'ExampleProject'; RepositoryId = 'repo-id' })

        $result[0].Path | Should -Be '/appsettings.U1.json'
        $result[0].ChangeType | Should -Be 'edit'
    }

    It 'returns the first supported change-entry list property' {
        $result = Get-GerberAdoPullRequestChangeEntryList -Response ([pscustomobject]@{ changes = @('a', 'b') })

        $result | Should -Be @('a', 'b')
    }
}

Describe 'Get-GerberAdoPullRequestLatestIterationId' {
    It '<Name>' -TestCases @(
        @{
            Name = 'returns the highest iteration id from the Azure DevOps response'
            ResponseValueList = @([pscustomobject]@{ id = 2 }, [pscustomobject]@{ id = 7 }, [pscustomobject]@{ id = 4 })
            ExpectedIterationId = 7
            ExpectedError = ''
        }
        @{
            Name = 'throws when Azure DevOps returns no iterations'
            ResponseValueList = @()
            ExpectedIterationId = $null
            ExpectedError = '*could not find any iterations*'
        }
    ) {
        param(
            [object[]]$ResponseValueList,
            [object]$ExpectedIterationId,
            [string]$ExpectedError
        )

        $mockResponseValueList = $ResponseValueList
        Mock Get-GerberAdoApiUri { [uri]'https://ado.example.test/iterations' }
        Mock Invoke-GerberAdoRestRequest { @{ value = $mockResponseValueList } }
        Mock Get-GerberAdoResponseValueList { $mockResponseValueList }

        if ([string]::IsNullOrWhiteSpace($ExpectedError)) {
            $result = Get-GerberAdoPullRequestLatestIterationId -Context (Get-ChangedFileContext) -PullRequest (Get-ChangedFilePullRequest)

            $result | Should -Be $ExpectedIterationId
            return
        }

        {
            Get-GerberAdoPullRequestLatestIterationId -Context (Get-ChangedFileContext) -PullRequest (Get-ChangedFilePullRequest)
        } | Should -Throw $ExpectedError
    }
}

Describe 'Get-GerberAdoPullRequestChangeUri' {
    It 'builds the changes API URI for the selected iteration' {
        Mock Get-GerberAdoApiUri { [uri]'https://ado.example.test/changes?iteration=7' }

        $result = Get-GerberAdoPullRequestChangeUri `
            -Context ([pscustomobject]@{
                Configuration = [pscustomobject]@{
                    CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                    DefaultApiVersion = '7.0'
                }
            }) `
            -PullRequest ([pscustomobject]@{
                PullRequestId = 18075
                ProjectName = 'ExampleProject'
                RepositoryId = 'repo-id'
            }) `
            -IterationId 7

        $result.AbsoluteUri | Should -Be 'https://ado.example.test/changes?iteration=7'
        Should -Invoke Get-GerberAdoApiUri -ParameterFilter {
            $QueryParameterMap['api-version'] -eq '7.0' -and
            $QueryParameterMap['$top'] -eq '2000'
        } -Times 1
    }
}

Describe 'Get-GerberAdoPullRequestChangeEntryList' {
    It 'returns an empty list when the response is null or unsupported' {
        @(Get-GerberAdoPullRequestChangeEntryList -Response $null).Count | Should -Be 0
        @(Get-GerberAdoPullRequestChangeEntryList -Response ([pscustomobject]@{ other = @('x') })).Count | Should -Be 0
    }

    It 'returns change entries from hashtable-backed responses' {
        $result = Get-GerberAdoPullRequestChangeEntryList -Response @{ value = @('a', 'b') }

        $result | Should -Be @('a', 'b')
    }
}

Describe 'Resolve-GerberAdoPullRequestPathValue' {
    It 'returns the requested path property when it exists and empty text otherwise' {
        (Resolve-GerberAdoPullRequestPathValue -ChangeEntry ([pscustomobject]@{ originalPath = '/old.json' }) -PropertyName 'originalPath') | Should -Be '/old.json'
        (Resolve-GerberAdoPullRequestPathValue -ChangeEntry ([pscustomobject]@{ path = '/new.json' }) -PropertyName 'originalPath') | Should -Be ''
    }
}

Describe 'Get-GerberAdoPullRequestChangeType' {
    It 'falls back to changeTrackingId when changeType is unavailable' {
        (Get-GerberAdoPullRequestChangeType -ChangeEntry ([pscustomobject]@{ changeTrackingId = 'rename' })) | Should -Be 'rename'
    }

    It 'returns empty text when no change type metadata is available' {
        (Get-GerberAdoPullRequestChangeType -ChangeEntry ([pscustomobject]@{ path = '/new.json' })) | Should -Be ''
    }
}
