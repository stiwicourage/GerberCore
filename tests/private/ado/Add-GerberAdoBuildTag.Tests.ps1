BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Add-GerberAdoBuildTag' {
    It 'adds a tag to the selected build' {
        Mock Get-GerberHttpConfiguration { [pscustomobject]@{ ConnectionTimeoutSeconds = 5; OperationTimeoutSeconds = 15 } }
        Mock Get-GerberAdoJsonRequestHeader { @{ Authorization = 'Basic abc' } }
        Mock Invoke-RestMethod {}

        Add-GerberAdoBuildTag `
            -Configuration ([pscustomobject]@{
                CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                ProjectName = 'ExampleProject'
                CredentialIdentifier = 'gerber:ado:example:pat'
            }) `
            -Pat 'pat' `
            -BuildId 9001 `
            -Tag 'Release-2026'

        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
            $Method -eq 'Put' -and
            $Uri.AbsoluteUri -eq 'https://ado.example.test/ExampleProject/ExampleProject/_apis/build/builds/9001/tags/Release-2026?api-version=7.1'
        }
    }

    It 'wraps build tag failures in a Gerber-owned argument error' {
        Mock Get-GerberHttpConfiguration { [pscustomobject]@{ ConnectionTimeoutSeconds = 5; OperationTimeoutSeconds = 15 } }
        Mock Get-GerberAdoJsonRequestHeader { @{ Authorization = 'Basic abc' } }
        Mock Invoke-RestMethod { throw [System.Exception]::new('Tag failed') }
        Mock Get-GerberAdoMutationFailureMessage { 'Tag wrapper.' }

        {
            Add-GerberAdoBuildTag `
                -Configuration ([pscustomobject]@{
                    CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                    ProjectName = 'ExampleProject'
                    CredentialIdentifier = 'gerber:ado:example:pat'
                }) `
                -Pat 'pat' `
                -BuildId 9001 `
                -Tag 'Juni release 2026'
        } | Should -Throw '*Tag wrapper.*'
    }
}
