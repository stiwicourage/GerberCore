BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Remove-GerberAdoBuildTag' {
    It 'deletes the requested build tag from Azure DevOps' {
        $configuration = [pscustomobject]@{
            CollectionUri          = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName            = 'ExampleProject'
            CredentialIdentifier = 'gerber:ado:example:pat'
        }
        Mock Get-GerberHttpConfiguration { [pscustomobject]@{ ConnectionTimeoutSeconds = 5; OperationTimeoutSeconds = 15 } }
        Mock Invoke-RestMethod {}

        Remove-GerberAdoBuildTag -Configuration $configuration -Pat 'pat' -BuildId 9001 -Tag 'Juni release 2026'

        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
            $Method -eq 'Delete' -and
            $Uri.AbsoluteUri -eq 'https://ado.example.test/ExampleProject/ExampleProject/_apis/build/builds/9001/tags/Juni%20release%202026?api-version=7.1'
        }
    }

    It 'ignores missing build tags' {
        $configuration = [pscustomobject]@{
            CollectionUri          = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName            = 'ExampleProject'
            CredentialIdentifier = 'gerber:ado:example:pat'
        }
        $notFound = [System.Exception]::new('404')
        $notFound | Add-Member -MemberType NoteProperty -Name Response -Value ([pscustomobject]@{ StatusCode = 404 })
        Mock Get-GerberHttpConfiguration { [pscustomobject]@{ ConnectionTimeoutSeconds = 5; OperationTimeoutSeconds = 15 } }
        Mock Invoke-RestMethod { throw $notFound }
        Mock Get-GerberAdoMutationFailureMessage { 'Should not be used.' }

        {
            Remove-GerberAdoBuildTag -Configuration $configuration -Pat 'pat' -BuildId 9001 -Tag 'Juni release 2026'
        } | Should -Not -Throw
    }

    It 'wraps build tag removal failures in a Gerber-owned argument error' {
        $configuration = [pscustomobject]@{
            CollectionUri          = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName            = 'ExampleProject'
            CredentialIdentifier = 'gerber:ado:example:pat'
        }
        Mock Get-GerberHttpConfiguration { [pscustomobject]@{ ConnectionTimeoutSeconds = 5; OperationTimeoutSeconds = 15 } }
        Mock Invoke-RestMethod { throw [System.Exception]::new('Delete failed') }
        Mock Get-GerberAdoMutationFailureMessage { 'Tag delete wrapper.' }

        {
            Remove-GerberAdoBuildTag -Configuration $configuration -Pat 'pat' -BuildId 9001 -Tag 'Juni release 2026'
        } | Should -Throw '*Tag delete wrapper.*'
    }
}

Describe 'Remove-GerberAdoBuildTag helpers' {
    It 'builds the delete URI and detects nested 404 responses' {
        $configuration = [pscustomobject]@{
            CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName   = 'ExampleProject'
        }
        $inner = [System.Exception]::new('404')
        $inner | Add-Member -MemberType NoteProperty -Name Response -Value ([pscustomobject]@{ StatusCode = 404 })
        $outer = [System.Exception]::new('Wrapped', $inner)

        (Get-GerberAdoBuildTagDeleteUri -Configuration $configuration -BuildId 9001 -Tag 'Juni release 2026').AbsoluteUri |
            Should -Be 'https://ado.example.test/ExampleProject/ExampleProject/_apis/build/builds/9001/tags/Juni%20release%202026?api-version=7.1'
        (Test-GerberAdoBuildTagMissingFailure -Exception $outer) | Should -BeTrue
    }

    It 'returns zero when the exception has no usable HTTP status response' {
        (Get-GerberAdoBuildTagFailureStatusCode -Exception $null) | Should -Be 0
        (Get-GerberAdoBuildTagFailureStatusCode -Exception ([System.Exception]::new('Boom'))) | Should -Be 0

        $nullResponse = [System.Exception]::new('Null response')
        $nullResponse | Add-Member -MemberType NoteProperty -Name Response -Value $null
        (Get-GerberAdoBuildTagFailureStatusCode -Exception $nullResponse) | Should -Be 0

        $withoutStatus = [System.Exception]::new('No status')
        $withoutStatus | Add-Member -MemberType NoteProperty -Name Response -Value ([pscustomobject]@{})
        (Get-GerberAdoBuildTagFailureStatusCode -Exception $withoutStatus) | Should -Be 0
    }
}
