BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot

    function Get-PullRequestFileContentContext {
        return [pscustomobject]@{
            Pat = 'pat'
            Configuration = [pscustomobject]@{
                CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                DefaultApiVersion = '7.0'
                CredentialIdentifier = 'gerber:ado:example:pat'
            }
        }
    }

    function Get-PullRequestFileContentPullRequest {
        return [pscustomobject]@{
            PullRequestId = 18075
            ProjectName = 'ExampleProject'
            RepositoryId = 'repo-id'
            SourceCommitId = 'abc123'
        }
    }

    function Invoke-PullRequestFileContentUnderTest {
        param(
            [string]$Path = '/README.md',
            [switch]$AllowMissing
        )

        return Get-GerberAdoPullRequestFileContent `
            -Context (Get-PullRequestFileContentContext) `
            -PullRequest (Get-PullRequestFileContentPullRequest) `
            -Path $Path `
            -AllowMissing:$AllowMissing
    }
}

Describe 'Get-GerberAdoPullRequestFileContent' {
    It '<Name>' -TestCases @(
        @{
            Name = 'returns string content from Invoke-WebRequest'
            ResponseContent = 'file content'
            Path = '/README.md'
            Expected = 'file content'
        }
        @{
            Name = 'removes a leading UTF-8 BOM from string content returned by Azure DevOps'
            ResponseContent = ([char]0xFEFF + '{ "AllowedHosts": "*" }')
            Path = '/appsettings.UC1.json'
            Expected = '{ "AllowedHosts": "*" }'
        }
        @{
            Name = 'decodes byte array content as UTF-8 text'
            ResponseContent = [System.Text.Encoding]::UTF8.GetBytes('hej verden')
            Path = '/README.md'
            Expected = 'hej verden'
        }
        @{
            Name = 'removes a leading UTF-8 BOM from UTF-8 byte content returned by Azure DevOps'
            ResponseContent = [byte[]]([byte[]](0xEF, 0xBB, 0xBF) + [System.Text.Encoding]::UTF8.GetBytes('{ "AllowedHosts": "*" }'))
            Path = '/appsettings.UC1.json'
            Expected = '{ "AllowedHosts": "*" }'
        }
    ) {
        param(
            [object]$ResponseContent,
            [string]$Path,
            [string]$Expected
        )

        $script:responseContentToReturn = $ResponseContent
        Mock Get-GerberAdoRequestHeader { @{ Authorization = 'Basic test' } }
        Mock Get-GerberHttpConfiguration { [pscustomobject]@{ ConnectionTimeoutSeconds = 5; OperationTimeoutSeconds = 15 } }
        Mock Get-GerberAdoApiUri { [uri]'https://ado.example.test/test' }
        Mock Invoke-WebRequest { [pscustomobject]@{ Content = $script:responseContentToReturn } }

        $result = Invoke-PullRequestFileContentUnderTest -Path $Path

        $result | Should -Be $Expected
    }

    It 'returns null for missing files when AllowMissing is used' {
        $exception = [System.Exception]::new('Not found')
        $exception | Add-Member -MemberType NoteProperty -Name Response -Value ([pscustomobject]@{ StatusCode = 404 })

        Mock Get-GerberAdoRequestHeader { @{ Authorization = 'Basic test' } }
        Mock Get-GerberHttpConfiguration { [pscustomobject]@{ ConnectionTimeoutSeconds = 5; OperationTimeoutSeconds = 15 } }
        Mock Get-GerberAdoApiUri { [uri]'https://ado.example.test/test' }
        Mock Invoke-WebRequest { throw $exception }

        $result = Invoke-PullRequestFileContentUnderTest -Path '/missing.json' -AllowMissing

        $result | Should -BeNull
    }

    It 'wraps request failures in a Gerber-owned argument exception' {
        $exception = [System.Exception]::new('Boom')

        Mock Get-GerberAdoRequestHeader { @{ Authorization = 'Basic test' } }
        Mock Get-GerberHttpConfiguration { [pscustomobject]@{ ConnectionTimeoutSeconds = 5; OperationTimeoutSeconds = 15 } }
        Mock Get-GerberAdoApiUri { [uri]'https://ado.example.test/test' }
        Mock Invoke-WebRequest { throw $exception }
        Mock Get-GerberAdoHttpStatusCode { 500 }
        Mock Get-GerberAdoRequestFailureMessage { 'Wrapped failure.' }

        {
            Invoke-PullRequestFileContentUnderTest
        } | Should -Throw 'Wrapped failure.'
    }

}

Describe 'Get-GerberTextWithoutLeadingUtf8Bom' {
    It 'returns null when the input text is null' {
        (Get-GerberTextWithoutLeadingUtf8Bom -Text $null) | Should -BeNull
    }

    It 'removes a leading UTF-8 BOM and leaves plain text unchanged' {
        (Get-GerberTextWithoutLeadingUtf8Bom -Text ([char]0xFEFF + 'hej')) | Should -Be 'hej'
        (Get-GerberTextWithoutLeadingUtf8Bom -Text 'hej') | Should -Be 'hej'
    }
}
