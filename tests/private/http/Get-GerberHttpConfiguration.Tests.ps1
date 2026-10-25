BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberHttpConfiguration' {
    It 'reads timeout defaults from Properties.json' {
        Mock Get-GerberPropertiesData {
            [pscustomobject]@{
                HttpConnectionTimeoutSeconds = 5
                HttpOperationTimeoutSeconds = 15
            }
        }

        $config = Get-GerberHttpConfiguration

        $config.ConnectionTimeoutSeconds | Should -Be 5
        $config.OperationTimeoutSeconds | Should -Be 15
    }
}
