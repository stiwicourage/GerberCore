BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot

    function Get-TestGerberAdoProfileConfiguration {
        return @{
            schemaVersion = 1
            ado = @{
                defaultProfile = 'example'
                profiles = [ordered]@{
                    example = @{
                        projectUrl = 'https://dev.azure.com/example-org/SampleProject'
                    }
                    Internal = @{
                        projectUrl = 'https://ado.example.com/tfs/DefaultCollection/MyProject'
                        deploymentType = 'Server'
                        serverUrl = 'https://ado.example.com/tfs'
                        note = 'keep-me'
                    }
                }
            }
        }
    }
}

Describe 'Get-GerberAdoConnectionProfile' {
    It 'returns all configured profiles when no name is supplied' {
        $result = @(Get-GerberAdoConnectionProfile -Configuration (Get-TestGerberAdoProfileConfiguration))

        $result.Name | Should -Be @('example', 'Internal')
        $result[1].PropertyMap.note | Should -Be 'keep-me'
    }

    It 'resolves a configured profile name case-insensitively while preserving its original casing' {
        $result = Get-GerberAdoConnectionProfile `
            -Name 'internal' `
            -Configuration (Get-TestGerberAdoProfileConfiguration)

        $result.Name | Should -Be 'Internal'
        $result.ServerUrl | Should -Be 'https://ado.example.com/tfs'
    }

    It 'returns null when the requested profile does not exist' {
        $result = Get-GerberAdoConnectionProfile `
            -Name 'missing' `
            -Configuration (Get-TestGerberAdoProfileConfiguration)

        $result | Should -BeNullOrEmpty
    }

    It 'returns an empty profile list when the configuration has no ado section' {
        $result = @(Get-GerberAdoConnectionProfile -Configuration @{ schemaVersion = 1 })

        $result | Should -Be @()
    }
}
