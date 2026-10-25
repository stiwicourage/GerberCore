BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Stop-GerberAdoPipelineRun' {
    It 'patches the build status to cancelling' {
        $configuration = [pscustomobject]@{
            CollectionUri          = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName            = 'ExampleProject'
            CredentialIdentifier = 'gerber:ado:example:pat'
        }
        Mock Get-GerberHttpConfiguration { [pscustomobject]@{ ConnectionTimeoutSeconds = 5; OperationTimeoutSeconds = 15 } }
        Mock Invoke-RestMethod {}

        Stop-GerberAdoPipelineRun -Configuration $configuration -Pat 'pat' -BuildId 9001

        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
            $Method -eq 'Patch' -and
            $Uri.AbsoluteUri -eq 'https://ado.example.test/ExampleProject/ExampleProject/_apis/build/builds/9001?api-version=7.1' -and
            $Body -match '"status"\s*:\s*"cancelling"'
        }
    }

    It 'wraps pipeline-stop failures in a Gerber-owned argument error' {
        $configuration = [pscustomobject]@{
            CollectionUri          = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName            = 'ExampleProject'
            CredentialIdentifier = 'gerber:ado:example:pat'
        }
        Mock Get-GerberHttpConfiguration { [pscustomobject]@{ ConnectionTimeoutSeconds = 5; OperationTimeoutSeconds = 15 } }
        Mock Invoke-RestMethod { throw [System.Exception]::new('Stop failed') }
        Mock Get-GerberAdoMutationFailureMessage { 'Stop wrapper.' }

        {
            Stop-GerberAdoPipelineRun -Configuration $configuration -Pat 'pat' -BuildId 9001
        } | Should -Throw '*Stop wrapper.*'
    }
}

Describe 'Stop-GerberAdoPipelineRun helpers' {
    It 'builds the build-update URI' {
        $configuration = [pscustomobject]@{
            CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName   = 'ExampleProject'
        }

        (Get-GerberAdoPipelineRunStopUri -Configuration $configuration -BuildId 9001).AbsoluteUri |
            Should -Be 'https://ado.example.test/ExampleProject/ExampleProject/_apis/build/builds/9001?api-version=7.1'
    }
}
