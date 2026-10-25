BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
    $script:assertPatchRequest = {
        param(
            [Parameter(Mandatory)]
            [object[]]$CallList
        )

        $CallList | Should -HaveCount 1
        $call = $CallList[0]
        $patchOperation = (ConvertFrom-Json -InputObject $call.Body)[0]

        $call.Method | Should -Be 'Patch'
        $call.Uri.AbsoluteUri | Should -Be 'https://dev.azure.com/example-org/SampleProject/_apis/wit/workitems/21279?api-version=7.1'
        $call.ConnectionTimeoutSeconds | Should -Be 11
        $call.OperationTimeoutSeconds | Should -Be 22
        $call.Headers.Authorization | Should -Be 'Basic encoded'
        $call.Headers.Accept | Should -Be 'application/json'
        $call.Headers.'Content-Type' | Should -Be 'application/json-patch+json'
        $patchOperation.op | Should -Be 'replace'
        $patchOperation.path | Should -Be '/fields/Custom.StatusiPreProd'
        $patchOperation.value | Should -Be 'Udført ✅'
    }
}

Describe 'Update-GerberAdoWorkItemFieldMap' {
    It 'patches the requested work item fields through Azure DevOps' {
        $script:restCallList = [System.Collections.Generic.List[object]]::new()
        Mock Get-GerberHttpConfiguration {
            [pscustomobject]@{
                ConnectionTimeoutSeconds = 11
                OperationTimeoutSeconds  = 22
            }
        }
        Mock Get-GerberAdoRequestHeader { @{ Authorization = 'Basic encoded' } }
        Mock Invoke-RestMethod {
            $null = $script:restCallList.Add([pscustomobject]@{
                    Method                   = $Method
                    Uri                      = $Uri
                    Headers                  = $Headers
                    Body                     = $Body
                    ConnectionTimeoutSeconds = $ConnectionTimeoutSeconds
                    OperationTimeoutSeconds  = $OperationTimeoutSeconds
                })
        }

        Update-GerberAdoWorkItemFieldMap -UpdateRequest ([pscustomobject]@{
                Configuration = [pscustomobject]@{
                    CollectionUri           = [uri]'https://dev.azure.com/example-org/'
                    ProjectName             = 'SampleProject'
                    CredentialIdentifier  = 'gerber:ado:example:pat'
                }
                Pat           = 'pat'
                WorkItemId    = 21279
                FieldValueMap = [ordered]@{
                    'Custom.StatusiPreProd' = 'Udført ✅'
                }
            })

        & $script:assertPatchRequest -CallList @($script:restCallList)
    }

    It 'rejects empty field updates' {
        {
            Update-GerberAdoWorkItemFieldMap -UpdateRequest ([pscustomobject]@{
                    Configuration = [pscustomobject]@{}
                    Pat           = 'pat'
                    WorkItemId    = 21279
                    FieldValueMap = @{}
                })
        } | Should -Throw 'Gerber plugin ADO work item updates require at least one field value.'
    }

    It 'wraps Azure DevOps failures with the shared mutation message' {
        Mock Get-GerberHttpConfiguration {
            [pscustomobject]@{
                ConnectionTimeoutSeconds = 11
                OperationTimeoutSeconds  = 22
            }
        }
        Mock Get-GerberAdoRequestHeader { @{ Authorization = 'Basic encoded' } }
        Mock Get-GerberAdoMutationFailureMessage { 'Wrapped failure.' }
        Mock Invoke-RestMethod { throw [System.InvalidOperationException]::new('Bad patch request') }

        {
            Update-GerberAdoWorkItemFieldMap -UpdateRequest ([pscustomobject]@{
                    Configuration = [pscustomobject]@{
                        CollectionUri           = [uri]'https://dev.azure.com/example-org/'
                        ProjectName             = 'SampleProject'
                        CredentialIdentifier  = 'gerber:ado:example:pat'
                    }
                    Pat           = 'pat'
                    WorkItemId    = 21279
                    FieldValueMap = [ordered]@{
                        'Custom.StatusiPreProd' = 'Udført ✅'
                    }
                })
        } | Should -Throw 'Wrapped failure.'
    }
}
