BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoEnvironmentList' {
    It 'requests pipeline environments and returns id and name' {
        $configuration = [pscustomobject]@{
            CollectionUri          = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName            = 'ExampleProject'
            CredentialIdentifier = 'gerber:ado:example:pat'
        }
        Mock Invoke-GerberAdoRestRequest {
            [pscustomobject]@{
                value = @(
                    [pscustomobject]@{ id = 1; name = 'PreProd' }
                    [pscustomobject]@{ id = 2; name = 'U3' }
                )
            }
        }

        $result = @(Get-GerberAdoEnvironmentList -Configuration $configuration -Pat 'pat')

        $result.Name | Should -Be @('PreProd', 'U3')
        Should -Invoke Invoke-GerberAdoRestRequest -Times 1 -ParameterFilter {
            $Uri.AbsoluteUri -eq 'https://ado.example.test/ExampleProject/ExampleProject/_apis/pipelines/environments?api-version=7.2-preview.1'
        }
    }
}

Describe 'Get-GerberAdoEnvironmentListUri' {
    It 'builds the pipelines environments API URI' {
        $configuration = [pscustomobject]@{
            CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName   = 'ExampleProject'
        }

        (Get-GerberAdoEnvironmentListUri -Configuration $configuration).AbsoluteUri |
            Should -Be 'https://ado.example.test/ExampleProject/ExampleProject/_apis/pipelines/environments?api-version=7.2-preview.1'
    }
}

Describe 'ConvertTo-GerberAdoEnvironmentItem' {
    It 'normalizes an Azure DevOps environment object' {
        $result = ConvertTo-GerberAdoEnvironmentItem -Environment ([pscustomobject]@{
                id   = '21'
                name = 'Prod'
            })

        $result.Id | Should -Be 21
        $result.Name | Should -Be 'Prod'
    }
}
