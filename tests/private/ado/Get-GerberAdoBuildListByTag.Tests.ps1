BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoBuildListByTag' {
    It 'returns every page of tagged builds' {
        $script:requestCount = 0
        Mock Invoke-GerberAdoBuildListByTagRequest {
            $script:requestCount++
            if ($script:requestCount -eq 1) {
                return [pscustomobject]@{
                    Response = [pscustomobject]@{
                        value = @(
                            [pscustomobject]@{
                                id = 101
                                buildNumber = '2026.01'
                                status = 'completed'
                                result = 'succeeded'
                                queueTime = '2026-06-19T08:00:00Z'
                                definition = [pscustomobject]@{ id = 11; name = 'Pipeline A' }
                            }
                        )
                    }
                    ResponseHeaders = @{ 'x-ms-continuationtoken' = 'next-page' }
                }
            }

            return [pscustomobject]@{
                Response = [pscustomobject]@{
                    value = @(
                        [pscustomobject]@{
                            id = 102
                            buildNumber = '2026.02'
                            status = 'inProgress'
                            result = $null
                            queueTime = '2026-06-19T09:00:00Z'
                            definition = [pscustomobject]@{ id = 12; name = 'Pipeline B' }
                        }
                    )
                }
                ResponseHeaders = @{}
            }
        }

        $result = Get-GerberAdoBuildListByTag `
            -Configuration ([pscustomobject]@{
                CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                ProjectName = 'ExampleProject'
            }) `
            -Pat 'pat' `
            -Tag 'Fixversion'

        $result.BuildId | Should -Be @(101, 102)
        $result.DefinitionName | Should -Be @('Pipeline A', 'Pipeline B')
        $result.RunUrl[0] | Should -Be 'https://ado.example.test/ExampleProject/ExampleProject/_build/results?buildId=101&view=results'
    }

    It 'treats a null page response envelope as an empty result' {
        Mock Invoke-GerberAdoBuildListByTagRequest { $null }

        $result = Get-GerberAdoBuildListByTag `
            -Configuration ([pscustomobject]@{
                CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                ProjectName = 'ExampleProject'
            }) `
            -Pat 'pat' `
            -Tag 'Fixversion'

        $result | Should -BeNullOrEmpty
    }
}

Describe 'Get-GerberAdoBuildListByTagUri' {
    It 'includes the tag filter and continuation token when present' {
        $result = Get-GerberAdoBuildListByTagUri `
            -Configuration ([pscustomobject]@{
                CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                ProjectName = 'ExampleProject'
            }) `
            -Tag 'Fix version' `
            -ContinuationToken 'abc123'

        $result.AbsoluteUri | Should -Match '^https://ado\.example\.test/ExampleProject/ExampleProject/_apis/build/builds\?'
        $result.Query | Should -Match 'api-version=7.1'
        $result.Query | Should -Match 'tagFilters=Fix%20version'
        $result.Query | Should -Match '%24top=200'
        $result.Query | Should -Match 'queryOrder=queueTimeDescending'
        $result.Query | Should -Match 'continuationToken=abc123'
    }
}

Describe 'Get-GerberAdoBuildListByTagContinuationToken' {
    It 'returns an empty continuation token when no headers are present' {
        $result = Get-GerberAdoBuildListByTagContinuationToken -ResponseHeaders $null

        $result | Should -Be ''
    }

    It 'returns the first continuation token value from response headers' {
        $result = Get-GerberAdoBuildListByTagContinuationToken -ResponseHeaders @{ 'x-ms-continuationtoken' = @('token-1', 'token-2') }

        $result | Should -Be 'token-1'
    }

    It 'reads the continuation token from object-style response headers' {
        $result = Get-GerberAdoBuildListByTagContinuationToken -ResponseHeaders ([pscustomobject]@{ 'x-ms-continuationtoken' = 'token-3' })

        $result | Should -Be 'token-3'
    }

    It 'reads the continuation token from generic dictionary response headers' {
        $responseHeaders = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.IEnumerable[string]]]::new()
        $responseHeaders.Add('x-ms-continuationtoken', [string[]]@('token-4'))

        $result = Get-GerberAdoBuildListByTagContinuationToken -ResponseHeaders $responseHeaders

        $result | Should -Be 'token-4'
    }
}

Describe 'Invoke-GerberAdoBuildListByTagRequest' {
    It 'returns the response and response headers from Invoke-RestMethod' {
        Mock Get-GerberHttpConfiguration { [pscustomobject]@{ ConnectionTimeoutSeconds = 5; OperationTimeoutSeconds = 15 } }
        Mock Get-GerberAdoRequestHeader { @{ Authorization = 'Basic abc' } }
        Mock Invoke-RestMethod {
            return [pscustomobject]@{ value = @() }
        }

        $result = Invoke-GerberAdoBuildListByTagRequest `
            -Configuration ([pscustomobject]@{
                CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                ProjectName = 'ExampleProject'
                CredentialIdentifier = 'gerber:ado:example:pat'
            }) `
            -Pat 'pat' `
            -Tag 'Fixversion'

        $result.Response.value | Should -Be @()
        $result.ResponseHeaders | Should -BeNullOrEmpty
    }

    It 'wraps request failures in a Gerber-owned argument error' {
        Mock Get-GerberHttpConfiguration { [pscustomobject]@{ ConnectionTimeoutSeconds = 5; OperationTimeoutSeconds = 15 } }
        Mock Get-GerberAdoRequestHeader { @{ Authorization = 'Basic abc' } }
        Mock Invoke-RestMethod { throw [System.Exception]::new('request failed') }
        Mock Test-GerberAdoRetriableFailure { $false }
        Mock Get-GerberAdoRequestFailureMessage { 'Wrapped request failure.' }

        {
            Invoke-GerberAdoBuildListByTagRequest `
                -Configuration ([pscustomobject]@{
                    CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                    ProjectName = 'ExampleProject'
                    CredentialIdentifier = 'gerber:ado:example:pat'
                }) `
                -Pat 'pat' `
                -Tag 'Fixversion'
        } | Should -Throw '*Wrapped request failure.*'
    }
}

Describe 'Get-GerberAdoBuildListByTag page helpers' {
    It 'returns empty values when the response envelope is missing expected properties' {
        $responseValue = Get-GerberAdoBuildListByTagEnvelopeProperty -ResponseEnvelope ([pscustomobject]@{}) -PropertyName 'Response'
        $responseHeaders = Get-GerberAdoBuildListByTagEnvelopeProperty -ResponseEnvelope ([pscustomobject]@{}) -PropertyName 'ResponseHeaders'

        $responseValue | Should -BeNullOrEmpty
        $responseHeaders | Should -BeNullOrEmpty
    }

    It 'returns empty build data and continuation token when the envelope is null' {
        Mock Invoke-GerberAdoBuildListByTagRequest { $null }

        $result = Get-GerberAdoBuildListByTagPageData `
            -Configuration ([pscustomobject]@{
                CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                ProjectName = 'ExampleProject'
            }) `
            -Pat 'pat' `
            -Tag 'Fixversion'

        $result.BuildList | Should -BeNullOrEmpty
        $result.ContinuationToken | Should -Be ''
    }
}

Describe 'ConvertTo-GerberAdoTaggedBuildList' {
    It 'normalizes tagged build fields and fallbacks' {
        $result = ConvertTo-GerberAdoTaggedBuildList `
            -Configuration ([pscustomobject]@{
                CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                ProjectName = 'ExampleProject'
            }) `
            -Response ([pscustomobject]@{
                value = @(
                    [pscustomobject]@{
                        id = 42
                        buildNumber = ''
                        status = ''
                        result = ''
                        queueTime = $null
                        definition = [pscustomobject]@{ id = 77; name = '' }
                    }
                )
            })

        $result[0].DefinitionName | Should -Be 'Pipeline 77'
        $result[0].BuildNumber | Should -Be 'Build 42'
        $result[0].QueueTime | Should -Be ([datetime]::MinValue)
        $result[0].QueueTimeText | Should -Be 'Unknown'
        $result[0].RunUrl | Should -Be 'https://ado.example.test/ExampleProject/ExampleProject/_build/results?buildId=42&view=results'
    }

    It 'tolerates tagged builds where Azure DevOps omits the result property' {
        $result = ConvertTo-GerberAdoTaggedBuildList `
            -Configuration ([pscustomobject]@{
                CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                ProjectName = 'ExampleProject'
            }) `
            -Response ([pscustomobject]@{
                value = @(
                    [pscustomobject]@{
                        id = 73193
                        buildNumber = '20260618.4'
                        status = 'inProgress'
                        queueTime = '2026-06-18T06:00:00Z'
                        definition = [pscustomobject]@{ id = 91; name = 'Deploy pipeline' }
                    }
                )
            })

        $result[0].Status | Should -Be 'inProgress'
        $result[0].Result | Should -Be ''
        $result[0].DefinitionName | Should -Be 'Deploy pipeline'
    }

    It 'returns an empty build list when the response does not contain a value property' {
        $result = ConvertTo-GerberAdoTaggedBuildList `
            -Configuration ([pscustomobject]@{
                CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                ProjectName = 'ExampleProject'
            }) `
            -Response ([pscustomobject]@{ count = 0 })

        $result | Should -BeNullOrEmpty
    }
}

Describe 'Get-GerberAdoTaggedBuildDisplayValue' {
    It 'returns the fallback when the value is empty and the value otherwise' {
        (Get-GerberAdoTaggedBuildDisplayValue -Value '' -FallbackValue 'fallback') | Should -Be 'fallback'
        (Get-GerberAdoTaggedBuildDisplayValue -Value 'named value' -FallbackValue 'fallback') | Should -Be 'named value'
    }
}

Describe 'Get-GerberAdoTaggedBuildPropertyValue' {
    It 'returns an empty string when the property is missing and the value otherwise' {
        (Get-GerberAdoTaggedBuildPropertyValue -InputObject ([pscustomobject]@{}) -PropertyName 'result') | Should -Be ''
        (Get-GerberAdoTaggedBuildPropertyValue -InputObject ([pscustomobject]@{ result = 'succeeded' }) -PropertyName 'result') | Should -Be 'succeeded'
    }
}

Describe 'Build queue-time helpers' {
    It 'parses queue times and formats non-empty queue time text' {
        $queueTime = ConvertTo-GerberAdoBuildQueueTime -QueueTime '2026-06-19T09:30:00Z'
        $result = Get-GerberAdoTaggedBuildQueueTimeText -QueueTime $queueTime

        $queueTime | Should -Be ([datetime]'2026-06-19T09:30:00Z')
        $result | Should -Match '^2026-06-19 \d{2}[:\.]30$'
    }
}
