BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Start-GerberAdoPipelineRun' {
    BeforeEach {
        Mock Get-GerberHttpConfiguration { [pscustomobject]@{ ConnectionTimeoutSeconds = 5; OperationTimeoutSeconds = 15 } }
    }

    It 'queues a build, tags it with Fixversion, and returns the run URL' {
        $configuration = [pscustomobject]@{
            CollectionUri          = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName            = 'ExampleProject'
            CredentialIdentifier = 'gerber:ado:example:pat'
        }
        $script:requestBodies = @()
        Mock Invoke-RestMethod {
            if ($Method -eq 'Post') {
                $script:requestBodies += $Body
                return [pscustomobject]@{ id = 9001 }
            }

            return @('Juni release 2026')
        }

        $result = Start-GerberAdoPipelineRun -RunRequest ([pscustomobject]@{
                Configuration = $configuration
                Pat           = 'pat'
                DefinitionId  = 53
                BranchName    = 'main'
                Fixversion    = 'Juni release 2026'
            })

        $result.BuildId | Should -Be 9001
        $result.RunUrl | Should -Be 'https://ado.example.test/ExampleProject/ExampleProject/_build/results?buildId=9001&view=results'
        $script:requestBodies[0] | Should -Match '"sourceBranch"\s*:\s*"refs/heads/main"'
        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
            $Method -eq 'Put' -and
            $Uri.AbsoluteUri -eq 'https://ado.example.test/ExampleProject/ExampleProject/_apis/build/builds/9001/tags/Juni%20release%202026?api-version=7.1'
        }
    }

    It 'adds missing carryover tags after the Fixversion tag' {
        $configuration = [pscustomobject]@{
            CollectionUri          = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName            = 'ExampleProject'
            CredentialIdentifier = 'gerber:ado:example:pat'
        }
        Mock Invoke-GerberAdoBuildQueueRequest { [pscustomobject]@{ id = 9001 } }
        Mock Add-GerberAdoBuildTag {}
        Mock Get-GerberAdoBuildTagList { @('Juni release 2026', 'keep-me') }

        $null = Start-GerberAdoPipelineRun -RunRequest ([pscustomobject]@{
                Configuration     = $configuration
                Pat               = 'pat'
                DefinitionId      = 53
                BranchName        = 'main'
                Fixversion        = 'Juni release 2026'
                CarryoverTagList  = @('keep-me', 'release-candidate', 'release-candidate')
            })

        Should -Invoke Add-GerberAdoBuildTag -Times 1 -ParameterFilter {
            $BuildId -eq 9001 -and
            $Tag -eq 'Juni release 2026'
        }
        Should -Invoke Add-GerberAdoBuildTag -Times 1 -ParameterFilter {
            $BuildId -eq 9001 -and
            $Tag -eq 'release-candidate'
        }
        Should -Invoke Add-GerberAdoBuildTag -Times 0 -ParameterFilter {
            $BuildId -eq 9001 -and
            $Tag -eq 'keep-me'
        }
    }

    It 'adds template parameters to the queue body when provided' {
        $configuration = [pscustomobject]@{
            CollectionUri          = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName            = 'ExampleProject'
            CredentialIdentifier = 'gerber:ado:example:pat'
        }
        $script:requestBodies = @()
        Mock Invoke-RestMethod {
            if ($Method -eq 'Post') {
                $script:requestBodies += $Body
                return [pscustomobject]@{ id = 9001 }
            }

            return @('Juni release 2026')
        }

        $null = Start-GerberAdoPipelineRun -RunRequest ([pscustomobject]@{
                Configuration       = $configuration
                Pat                 = 'pat'
                DefinitionId        = 53
                BranchName          = 'main'
                Fixversion          = 'Juni release 2026'
                TemplateParameterMap = @{
                    environmentName   = 'U1'
                    JreVersion        = '17.0.10'
                    JrePackageVersion = '17.0.10+7'
                    JreDownloadUrl    = 'https://packages.example.test/repository/Common/Solr/Solr-9.6.1/openlogic-openjdk-jre-17.0.10%2B7-windows-x64.zip'
                }
            })

        $script:requestBodies[0] | Should -Match '"templateParameters"\s*:'
        $script:requestBodies[0] | Should -Match '"environmentName"\s*:\s*"U1"'
        $script:requestBodies[0] | Should -Match '"JreVersion"\s*:\s*"17.0.10"'
        $script:requestBodies[0] | Should -Match '"JrePackageVersion"\s*:\s*"17.0.10\+7"'
        $script:requestBodies[0] | Should -Match '"JreDownloadUrl"\s*:\s*"https://packages\.example\.test/repository/Common/Solr/Solr-9\.6\.1/openlogic-openjdk-jre-17\.0\.10%2B7-windows-x64\.zip"'
    }

    It 'accepts already normalized refs/heads branch names' {
        (Get-GerberAdoBuildSourceBranch -BranchName 'refs/heads/Releases/R2026-06') | Should -Be 'refs/heads/Releases/R2026-06'
    }
}

Describe 'Start-GerberAdoPipelineRun helpers' {
    It 'builds queue, tag, and run URLs from the ADO configuration' {
        $configuration = [pscustomobject]@{
            CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName   = 'ExampleProject'
        }

        (Get-GerberAdoBuildQueueUri -Configuration $configuration).AbsoluteUri |
            Should -Be 'https://ado.example.test/ExampleProject/ExampleProject/_apis/build/builds?api-version=7.1'
        (Get-GerberAdoBuildTagUri -Configuration $configuration -BuildId 9001 -Tag 'Juni release 2026').AbsoluteUri |
            Should -Be 'https://ado.example.test/ExampleProject/ExampleProject/_apis/build/builds/9001/tags/Juni%20release%202026?api-version=7.1'
        (Get-GerberAdoBuildRunUrl -Configuration $configuration -BuildId 9001) |
            Should -Be 'https://ado.example.test/ExampleProject/ExampleProject/_build/results?buildId=9001&view=results'
    }

    It 'returns the queued build id from hashtable and object responses' {
        (Get-GerberAdoQueuedBuildId -QueuedBuild @{ id = 12 } -DefinitionId 53) | Should -Be 12
        (Get-GerberAdoQueuedBuildId -QueuedBuild ([pscustomobject]@{ id = 13 }) -DefinitionId 53) | Should -Be 13
    }

    It 'returns an empty template parameter map when none are provided' {
        $result = Get-GerberAdoBuildTemplateParameterMap -RunRequest ([pscustomobject]@{
                DefinitionId = 53
            })

        $result.Count | Should -Be 0
    }

    It 'adds template parameters only when the map has values' {
        $bodyData = @{ definition = @{ id = 53 } }

        Add-GerberAdoBuildTemplateParameterMap -BodyData $bodyData -TemplateParameterMap @{}
        $bodyData.ContainsKey('templateParameters') | Should -BeFalse

        Add-GerberAdoBuildTemplateParameterMap -BodyData $bodyData -TemplateParameterMap @{ environmentName = 'U1' }
        $bodyData['templateParameters'].environmentName | Should -Be 'U1'
    }

    It 'throws when Azure DevOps returns no build id' {
        { Get-GerberAdoQueuedBuildId -QueuedBuild ([pscustomobject]@{}) -DefinitionId 53 } |
            Should -Throw "*did not receive a build ID*"
    }

    It 'returns carryover tags only when they are present on the run request' {
        (Get-GerberAdoBuildCarryoverTagList -RunRequest ([pscustomobject]@{})).Count | Should -Be 0
        (Get-GerberAdoBuildCarryoverTagList -RunRequest ([pscustomobject]@{ CarryoverTagList = @('keep-me', '', 'release-candidate') })) |
            Should -Be @('keep-me', 'release-candidate')
    }

    It 'builds a case-insensitive tag set from the current run tags' {
        Mock Get-GerberAdoBuildTagList { @('Juni release 2026', 'Keep-Me') }

        $result = Get-GerberAdoBuildTagSet `
            -Configuration ([pscustomobject]@{}) `
            -Pat 'pat' `
            -BuildId 9001

        $result.Contains('keep-me') | Should -BeTrue
        $result.Contains('JUNI RELEASE 2026') | Should -BeTrue
    }

    It 'adds JSON headers on top of the PAT authorization header' {
        Mock Get-GerberAdoRequestHeader { @{ Authorization = 'Basic abc' } }

        $result = Get-GerberAdoJsonRequestHeader -Pat 'pat'

        $result.Authorization | Should -Be 'Basic abc'
        $result.Accept | Should -Be 'application/json'
        $result.'Content-Type' | Should -Be 'application/json'
    }

    It '<Name>' -TestCases @(
        @{ Name = 'returns an unauthorized mutation hint when the PAT is rejected'; Unauthorized = $true; Hint = ''; Failure = [System.Exception]::new('401'); Expected = 'Update PAT credential' }
        @{ Name = 'returns a transport hint when the request cannot reach Azure DevOps'; Unauthorized = $false; Hint = 'DNS lookup failed.'; Failure = [System.Exception]::new('transport'); Expected = 'DNS lookup failed' }
        @{ Name = 'falls back to the exception message for other mutation failures'; Unauthorized = $false; Hint = ''; Failure = [System.Exception]::new('Boom'); Expected = 'Boom' }
        @{ Name = 'falls back to a generic retry message when the exception is null'; Unauthorized = $false; Hint = ''; Failure = $null; Expected = 'Try again in a moment' }
    ) {
        param($Unauthorized, $Hint, $Failure, $Expected)

        $script:unauthorizedFailure = $Unauthorized
        $script:transportFailureHint = $Hint
        Mock Test-GerberAdoUnauthorizedFailure { $script:unauthorizedFailure }
        Mock Get-GerberHttpTransportFailureHint { $script:transportFailureHint }

        $result = Get-GerberAdoMutationFailureMessage `
            -Uri ([uri]'https://ado/_apis/build/builds') `
            -RequestLabel 'queue pipeline definition 53' `
            -CredentialIdentifier 'gerber:ado:example:pat' `
            -Exception $Failure

        $result | Should -Match $Expected
    }

    It 'wraps queue request failures in a Gerber-owned argument error' {
        Mock Get-GerberHttpConfiguration { [pscustomobject]@{ ConnectionTimeoutSeconds = 5; OperationTimeoutSeconds = 15 } }
        Mock Get-GerberAdoJsonRequestHeader { @{ Authorization = 'Basic abc' } }
        Mock Invoke-RestMethod { throw [System.Exception]::new('Queue failed') }
        Mock Get-GerberAdoMutationFailureMessage { 'Queue wrapper.' }

        {
            Invoke-GerberAdoBuildQueueRequest `
                -QueueRequest ([pscustomobject]@{
                    QueueUri      = [uri]'https://ado/_apis/build/builds'
                    Configuration = [pscustomobject]@{ CredentialIdentifier = 'gerber:ado:example:pat' }
                    Pat           = 'pat'
                    DefinitionId  = 53
                    SourceBranch  = 'refs/heads/main'
                })
        } | Should -Throw '*Queue wrapper.*'
    }

}
