BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoWorkItemFieldMap' {
    It 'returns the work item fields as a hashtable' {
        Mock Invoke-GerberAdoRestRequest {
            [pscustomobject]@{
                fields = [pscustomobject]@{
                    'System.Title' = 'Release task'
                    'Custom.StepByStepGuide' = '<p>Parter</p>'
                }
            }
        }

        $result = Get-GerberAdoWorkItemFieldMap -WorkItemRequest ([pscustomobject]@{
                Configuration = [pscustomobject]@{
                    CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                    ProjectName = 'ExampleProject'
                    CredentialIdentifier = 'GERBER_TEST_PAT'
                }
                Pat = 'pat'
                WorkItemId = 21573
            })

        $result['System.Title'] | Should -Be 'Release task'
        $result['Custom.StepByStepGuide'] | Should -Be '<p>Parter</p>'
    }
}

Describe 'Get-GerberAdoWorkItemFieldMap helpers' {
    It 'builds the Azure DevOps work item URI' {
        $result = Get-GerberAdoWorkItemUri -WorkItemRequest ([pscustomobject]@{
                Configuration = [pscustomobject]@{
                    CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                    ProjectName = 'ExampleProject'
                }
                WorkItemId = 21573
            })

        $result.AbsoluteUri | Should -Be 'https://ado.example.test/ExampleProject/ExampleProject/_apis/wit/workitems/21573?api-version=7.1'
    }

    It 'throws when the Azure DevOps response does not include fields' {
        {
            ConvertTo-GerberAdoWorkItemFieldMap `
                -Response ([pscustomobject]@{ id = 21573 }) `
                -WorkItemId 21573
        } | Should -Throw "*could not read fields*"
    }

    It 'converts a field object to a hashtable' {
        $result = ConvertTo-GerberAdoFieldMap -FieldObject ([pscustomobject]@{
                'System.Title' = 'Release task'
                'Custom.StepByStepGuide' = '<p>Parter</p>'
            })

        $result.Keys | Sort-Object | Should -Be @('Custom.StepByStepGuide', 'System.Title')
    }
}
