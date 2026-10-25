BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberAdoRetentionLeaseTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Add-GerberAdoBuildRetentionLeaseIfMissing' {
    It 'creates a retention lease when Gerber has not retained the run yet' {
        $configuration = [pscustomobject]@{
            CollectionUri          = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName            = 'ExampleProject'
            CredentialIdentifier = 'gerber:ado:example:pat'
        }
        Mock Get-GerberHttpConfiguration { [pscustomobject]@{ ConnectionTimeoutSeconds = 5; OperationTimeoutSeconds = 15 } }
        Mock Get-GerberAdoRequestHeader { @{ Authorization = 'Basic abc' } }
        Mock Get-GerberAdoJsonRequestHeader { @{ Authorization = 'Basic abc' } }
        Mock Invoke-RestMethod {
            if ($Method -eq 'Get') {
                return [pscustomobject]@{ value = @() }
            }

            return @([pscustomobject]@{
                    leaseId   = 41
                    ownerId   = 'Gerber.ProdRetention'
                    definitionId = 53
                    runId     = 9001
                })
        }

        $result = Add-GerberAdoBuildRetentionLeaseIfMissing -Configuration $configuration -Pat 'pat' -DefinitionId 53 -BuildId 9001

        $result.Created | Should -BeTrue
        $result.LeaseList[0].leaseId | Should -Be 41
        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
            $Method -eq 'Get' -and
            $Uri.AbsoluteUri -match '^https://ado\.example\.test/ExampleProject/ExampleProject/_apis/build/retention/leases\?' -and
            (Test-GerberRetentionLeaseQuery -Query $Uri.Query)
        }
        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
            $Method -eq 'Post' -and
            $Uri.AbsoluteUri -eq 'https://ado.example.test/ExampleProject/ExampleProject/_apis/build/retention/leases?api-version=7.1' -and
            (Test-GerberRetentionLeaseBody -Body $Body)
        }
    }

    It 'skips creation when the run already has a Gerber retention lease' {
        Mock Get-GerberHttpConfiguration { [pscustomobject]@{ ConnectionTimeoutSeconds = 5; OperationTimeoutSeconds = 15 } }
        Mock Get-GerberAdoRequestHeader { @{ Authorization = 'Basic abc' } }
        Mock Get-GerberAdoJsonRequestHeader { @{ Authorization = 'Basic abc' } }
        Mock Invoke-RestMethod {
            [pscustomobject]@{
                value = @([pscustomobject]@{
                        leaseId      = 42
                        ownerId      = 'Gerber.ProdRetention'
                        definitionId = 53
                        runId        = 9001
                    })
            }
        }

        $result = Add-GerberAdoBuildRetentionLeaseIfMissing `
            -Configuration ([pscustomobject]@{
                    CollectionUri          = [uri]'https://ado.example.test/ExampleProject/'
                    ProjectName            = 'ExampleProject'
                    CredentialIdentifier = 'gerber:ado:example:pat'
                }) `
            -Pat 'pat' `
            -DefinitionId 53 `
            -BuildId 9001

        $result.Created | Should -BeFalse
        $result.LeaseList[0].leaseId | Should -Be 42
        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter { $Method -eq 'Get' }
        Should -Invoke Invoke-RestMethod -Times 0 -ParameterFilter { $Method -eq 'Post' }
    }

    It 'wraps retention-lookup failures in a Gerber-owned argument error' {
        Mock Get-GerberHttpConfiguration { [pscustomobject]@{ ConnectionTimeoutSeconds = 5; OperationTimeoutSeconds = 15 } }
        Mock Get-GerberAdoRequestHeader { @{ Authorization = 'Basic abc' } }
        Mock Invoke-RestMethod { throw [System.Exception]::new('Lookup failed') }
        Mock Get-GerberAdoRequestFailureMessage { 'Retention lookup wrapper.' }

        {
            Add-GerberAdoBuildRetentionLeaseIfMissing `
                -Configuration ([pscustomobject]@{
                        CollectionUri          = [uri]'https://ado.example.test/ExampleProject/'
                        ProjectName            = 'ExampleProject'
                        CredentialIdentifier = 'gerber:ado:example:pat'
                    }) `
                -Pat 'pat' `
                -DefinitionId 53 `
                -BuildId 9001
        } | Should -Throw '*Retention lookup wrapper.*'
    }

    It 'wraps retention-create failures in a Gerber-owned argument error' {
        Mock Get-GerberHttpConfiguration { [pscustomobject]@{ ConnectionTimeoutSeconds = 5; OperationTimeoutSeconds = 15 } }
        Mock Get-GerberAdoRequestHeader { @{ Authorization = 'Basic abc' } }
        Mock Get-GerberAdoJsonRequestHeader { @{ Authorization = 'Basic abc' } }
        Mock Invoke-RestMethod {
            if ($Method -eq 'Get') {
                return [pscustomobject]@{ value = @() }
            }

            throw [System.Exception]::new('Create failed')
        }
        Mock Get-GerberAdoMutationFailureMessage { 'Retention create wrapper.' }

        {
            Add-GerberAdoBuildRetentionLeaseIfMissing `
                -Configuration ([pscustomobject]@{
                        CollectionUri          = [uri]'https://ado.example.test/ExampleProject/'
                        ProjectName            = 'ExampleProject'
                        CredentialIdentifier = 'gerber:ado:example:pat'
                    }) `
                -Pat 'pat' `
                -DefinitionId 53 `
                -BuildId 9001
        } | Should -Throw '*Retention create wrapper.*'
    }
}

Describe 'Add-GerberAdoBuildRetentionLeaseIfMissing helpers' {
    It 'returns the value envelope when Azure DevOps wraps the lease list' {
        $result = Get-GerberAdoBuildRetentionLeaseResponseValueList -Response ([pscustomobject]@{
                value = @([pscustomobject]@{ leaseId = 42 })
            })

        $result[0].leaseId | Should -Be 42
    }
}
