BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoPendingApprovalList' {
    It 'reads pending approvals and keeps the build owner metadata from the 7.2 payload' {
        $configuration = [pscustomobject]@{
            CollectionUri          = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName            = 'ExampleProject'
            CredentialIdentifier = 'gerber:ado:example:pat'
        }
        Mock Invoke-GerberAdoRestRequest {
            [pscustomobject]@{
                value = @(
                    [pscustomobject]@{
                        id = 'approval-1'
                        status = 'pending'
                        pipeline = [pscustomobject]@{
                            id = '313'
                            name = 'Deploy Solr Core'
                            owner = [pscustomobject]@{
                                id = 72513
                                name = '20260607.2'
                            }
                        }

                    }
                )
            }
        }

        $result = @(Get-GerberAdoPendingApprovalList -Configuration $configuration -Pat 'pat' -EnvironmentId 11)

        $result[0].ApprovalId | Should -Be 'approval-1'
        $result[0].DefinitionId | Should -Be 313
        $result[0].RunId | Should -Be 72513
        $result[0].RunName | Should -Be '20260607.2'
        Should -Invoke Invoke-GerberAdoRestRequest -Times 1 -ParameterFilter {
            $Uri.AbsoluteUri -match 'api-version=7.2-preview.2' -and
            $Uri.AbsoluteUri -match 'state=pending' -and
            $Uri.AbsoluteUri -match 'environmentId=11' -and
            $Uri.AbsoluteUri -match '%24expand=steps'
        }
    }

    Describe 'Get-GerberAdoPendingApprovalList helpers' {
        It 'returns empty strings for missing flat and nested approval properties' {
            (Get-GerberAdoPendingApprovalPropertyValue -Approval ([pscustomobject]@{}) -PropertyName 'status') | Should -Be ''
            (Get-GerberAdoPendingApprovalNestedValue -InputObject $null -PropertyPath @('pipeline', 'owner')) | Should -Be ''
            (Get-GerberAdoPendingApprovalNestedValue -InputObject ([pscustomobject]@{ pipeline = $null }) -PropertyPath @('pipeline', 'owner')) | Should -Be ''
            (Get-GerberAdoPendingApprovalNestedValue -InputObject ([pscustomobject]@{ pipeline = $null }) -PropertyPath @('pipeline')) | Should -Be ''
        }

        It 'reads hashtable values and returns null for missing object properties' {
            (Get-GerberAdoPendingApprovalObjectPropertyValue -InputObject $null -PropertyName 'id') | Should -Be $null
            (Get-GerberAdoPendingApprovalObjectPropertyValue -InputObject @{ id = 'approval-1' } -PropertyName 'id') | Should -Be 'approval-1'
            (Get-GerberAdoPendingApprovalObjectPropertyValue -InputObject ([pscustomobject]@{}) -PropertyName 'id') | Should -Be $null
        }
    }

    It 'omits the environment filter when no environment id is supplied' {
        $configuration = [pscustomobject]@{
            CollectionUri          = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName            = 'ExampleProject'
            CredentialIdentifier = 'gerber:ado:example:pat'
        }
        Mock Invoke-GerberAdoRestRequest { [pscustomobject]@{ value = @() } }

        $null = @(Get-GerberAdoPendingApprovalList -Configuration $configuration -Pat 'pat')

        Should -Invoke Invoke-GerberAdoRestRequest -Times 1 -ParameterFilter {
            $Uri.AbsoluteUri -match 'api-version=7.2-preview.2' -and
            $Uri.AbsoluteUri -match 'state=pending' -and
            $Uri.AbsoluteUri -notmatch 'environmentId=' -and
            $Uri.AbsoluteUri -match '%24expand=steps'
        }
    }
}
