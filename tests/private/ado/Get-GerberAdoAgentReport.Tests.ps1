BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoAgentReport' {
    It 'writes Connecting status message before making HTTP calls' {
        Mock Write-GerberScreenLine {}
        Mock Get-GerberAdoConfiguration {
            [pscustomobject]@{
                CredentialIdentifier = 'gerber:ado:example:pat'
            }
        }
        Mock Resolve-GerberAdoPat { 'pat-value' }
        Mock Get-GerberAdoPoolList { @() }

        Get-GerberAdoAgentReport

        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter {
            $Text -eq 'Connecting to Azure DevOps...'
        }
    }

    It 'orders sections, pools, agents, and unique versions' {
        Mock Get-GerberAdoConfiguration {
            [pscustomobject]@{
                CredentialIdentifier = 'gerber:ado:example:pat'
            }
        }
        Mock Resolve-GerberAdoPat { 'pat-value' }
        Mock Get-GerberAdoPoolList {
            if ($PoolType -eq 'automation') {
                return @(
                    [pscustomobject]@{ Id = 2; Name = 'Zulu Pool' }
                    [pscustomobject]@{ Id = 1; Name = 'Alpha Pool' }
                )
            }

            return @(
                [pscustomobject]@{ Id = 3; Name = 'Deploy Pool' }
            )
        }
        Mock Get-GerberAdoPoolAgentList {
            switch ($Pool.Name) {
                'Alpha Pool' {
                    return @(
                        [pscustomobject]@{ Name = 'z-agent'; Version = '3.225.0'; Status = 'online' }
                        [pscustomobject]@{ Name = 'a-agent'; Version = '3.224.1'; Status = 'offline' }
                    )
                }
                'Zulu Pool' {
                    return @()
                }
                default {
                    return @(
                        [pscustomobject]@{ Name = 'deploy-agent'; Version = '3.225.0'; Status = 'online' }
                    )
                }
            }
        }

        $result = Get-GerberAdoAgentReport

        $result.Sections.Name | Should -Be @('BUILD', 'DEPLOY')
        $result.Sections[0].PoolList.Name | Should -Be @('Alpha Pool', 'Zulu Pool')
        $result.Sections[0].PoolList[0].AgentList.Name | Should -Be @('a-agent', 'z-agent')
        $result.Sections[0].PoolList[1].AgentList | Should -BeNullOrEmpty
        $result.VersionList | Should -Be @('3.224.1', '3.225.0')
    }

    It 'parses pool and agent responses through the shared response helpers' {
        $configuration = [pscustomobject]@{
            CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
            PoolApiVersion = '7.1'
            CredentialIdentifier = 'gerber:ado:example:pat'
        }

        Mock Invoke-GerberAdoRestRequest {
            if ($RequestLabel -eq 'automation pools') {
                return @{
                    value = @(
                        @{ id = 10; name = 'Build Pool' }
                    )
                }
            }

            return @{
                value = @(
                    @{ name = 'agent-01'; version = '3.225.0'; status = 'online' }
                )
            }
        }

        $poolList = Get-GerberAdoPoolList -Configuration $configuration -Pat 'pat' -PoolType 'automation'
        $agentList = Get-GerberAdoPoolAgentList -Configuration $configuration -Pat 'pat' -Pool ([pscustomobject]@{ Id = 10; Name = 'Build Pool' })

        $poolList[0].Name | Should -Be 'Build Pool'
        $agentList[0].Version | Should -Be '3.225.0'
        $agentList[0].Status | Should -Be 'online'
    }

    It 'builds the expected Azure DevOps pool and agent URIs' {
        $configuration = [pscustomobject]@{
            CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
            PoolApiVersion = '7.1'
        }

        $poolUri = (Get-GerberAdoPoolResourceUri `
                -Configuration $configuration `
                -RelativePath '_apis/distributedtask/pools' `
                -QueryParameterMap ([ordered]@{ poolType = 'automation' })).AbsoluteUri
        $agentUri = (Get-GerberAdoPoolResourceUri `
                -Configuration $configuration `
                -RelativePath '_apis/distributedtask/pools/12/agents' `
                -QueryParameterMap ([ordered]@{ includeCapabilities = 'false' })).AbsoluteUri

        $poolUri | Should -Match '^https://ado\.example\.test/ExampleProject/_apis/distributedtask/pools\?'
        $poolUri | Should -Match 'poolType=automation'
        $poolUri | Should -Match 'api-version=7.1'
        $agentUri | Should -Match '^https://ado\.example\.test/ExampleProject/_apis/distributedtask/pools/12/agents\?'
        $agentUri | Should -Match 'includeCapabilities=false'
        $agentUri | Should -Match 'api-version=7.1'
    }

    It 'normalizes response value lists and missing agent metadata' {
        (Get-GerberAdoResponseValueList -Response $null) | Should -BeNullOrEmpty
        (Get-GerberAdoResponseValueList -Response @{ value = @('a', 'b') }) | Should -Be @('a', 'b')
        (Get-GerberAdoResponseValueList -Response ([pscustomobject]@{ other = 1 })) | Should -BeNullOrEmpty
        (Get-GerberAdoAgentPropertyText -Agent ([pscustomobject]@{ version = '' }) -PropertyName 'version') | Should -Be 'unknown'
        (Get-GerberAdoAgentPropertyText -Agent ([pscustomobject]@{ status = '' }) -PropertyName 'status') | Should -Be 'unknown'
    }
}
