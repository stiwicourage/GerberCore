BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Resolve-GerberAdoPipelineDefinitionFromUrl' {
    It 'reads the definition id from the URL and returns the resolved definition name' {
        $configuration = [pscustomobject]@{
            CollectionUri          = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName            = 'ExampleProject'
            CredentialIdentifier = 'gerber:ado:example:pat'
        }
        Mock Invoke-GerberAdoRestRequest { [pscustomobject]@{ id = 53; name = 'ATaaS_CDM_Parter' } }

        $result = Resolve-GerberAdoPipelineDefinitionFromUrl `
            -Configuration $configuration `
            -Pat 'pat' `
            -PipelineUrl ([uri]'https://ado.example.test/ExampleProject/ExampleProject/_build?definitionId=53')

        $result.Id | Should -Be 53
        $result.Name | Should -Be 'ATaaS_CDM_Parter'
    }

    It 'throws when the URL has no definition id' {
        $configuration = [pscustomobject]@{
            CollectionUri          = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName            = 'ExampleProject'
            CredentialIdentifier = 'gerber:ado:example:pat'
        }

        {
            Resolve-GerberAdoPipelineDefinitionFromUrl `
                -Configuration $configuration `
                -Pat 'pat' `
                -PipelineUrl ([uri]'https://ado.example.test/ExampleProject/ExampleProject/_build')
        } | Should -Throw "*could not read an Azure DevOps pipeline definition ID*"
    }
}

Describe 'Get-GerberAdoBuildDefinitionId' {
    It 'extracts the definition id from a build URL query string' {
        (Get-GerberAdoBuildDefinitionId -PipelineUrl ([uri]'https://ado/_build?view=results&definitionId=53')) | Should -Be 53
    }
}

Describe 'Get-GerberAdoBuildDefinitionUri' {
    It 'builds the build definition API URI' {
        $configuration = [pscustomobject]@{
            CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName   = 'ExampleProject'
        }

        (Get-GerberAdoBuildDefinitionUri -Configuration $configuration -DefinitionId 53).AbsoluteUri |
            Should -Be 'https://ado.example.test/ExampleProject/ExampleProject/_apis/build/definitions/53?api-version=7.1'
    }
}

Describe 'ConvertTo-GerberResolvedBuildDefinition' {
    It 'throws when the definition name is missing' {
        {
            ConvertTo-GerberResolvedBuildDefinition `
                -Response ([pscustomobject]@{ id = 53 }) `
                -PipelineUrl ([uri]'https://ado/_build?definitionId=53') `
                -DefinitionId 53
        } | Should -Throw "*could not read the Azure DevOps pipeline definition name*"
    }
}

Describe 'Get-GerberResolvedBuildDefinitionPropertyValue' {
    It 'reads values from a hashtable response' {
        (Get-GerberResolvedBuildDefinitionPropertyValue -Response @{ name = 'ATaaS CDM Parter' } -PropertyName 'name') |
            Should -Be 'ATaaS CDM Parter'
    }

    It 'returns empty text when the property is missing' {
        (Get-GerberResolvedBuildDefinitionPropertyValue -Response ([pscustomobject]@{ id = 53 }) -PropertyName 'name') |
            Should -Be ''
    }

    It 'returns empty text when the response itself is null' {
        (Get-GerberResolvedBuildDefinitionPropertyValue -Response $null -PropertyName 'name') |
            Should -Be ''
    }
}
