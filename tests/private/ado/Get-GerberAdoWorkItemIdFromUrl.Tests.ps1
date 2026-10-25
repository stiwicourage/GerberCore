BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoWorkItemIdFromUrl' {
    It 'extracts the work item id from the URL path' {
        (Get-GerberAdoWorkItemIdFromUrl -WorkItemUrl 'https://ado.example.test/ExampleProject/ExampleProject/_workitems/edit/21279') |
            Should -Be 21279
    }

    It 'throws when the URL does not contain a work item id' {
        {
            Get-GerberAdoWorkItemIdFromUrl -WorkItemUrl 'https://ado.example.test/ExampleProject/ExampleProject/_build/results?buildId=72513'
        } | Should -Throw '*could not read an Azure DevOps work item ID*'
    }
}
