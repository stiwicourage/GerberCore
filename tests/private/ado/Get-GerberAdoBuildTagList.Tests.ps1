BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoBuildTagList' {
    It 'reads all build tags through the shared Azure DevOps GET helper' {
        $configuration = [pscustomobject]@{
            CollectionUri          = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName            = 'ExampleProject'
            CredentialIdentifier = 'gerber:ado:example:pat'
        }
        Mock Invoke-GerberAdoRestRequest { @{ value = @('Juni release 2026', 'keep-me') } }

        $result = @(Get-GerberAdoBuildTagList -Configuration $configuration -Pat 'pat' -BuildId 9001)

        $result | Should -Be @('Juni release 2026', 'keep-me')
        Should -Invoke Invoke-GerberAdoRestRequest -Times 1 -ParameterFilter {
            $Uri.AbsoluteUri -eq 'https://ado.example.test/ExampleProject/ExampleProject/_apis/build/builds/9001/tags?api-version=7.1' -and
            $RequestLabel -eq 'tags for build 9001' -and
            $PatAccountIdentifier -eq 'gerber:ado:example:pat'
        }
    }
}

Describe 'Get-GerberAdoBuildTagList helpers' {
    It 'builds the tag-list URI and stringifies tag values' {
        $configuration = [pscustomobject]@{
            CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName   = 'ExampleProject'
        }

        (Get-GerberAdoBuildTagListUri -Configuration $configuration -BuildId 9001).AbsoluteUri |
            Should -Be 'https://ado.example.test/ExampleProject/ExampleProject/_apis/build/builds/9001/tags?api-version=7.1'
        (ConvertTo-GerberAdoBuildTagText -Tag ' release ') | Should -Be 'release'
        (ConvertTo-GerberAdoBuildTagText -Tag $null) | Should -Be ''
    }
}
