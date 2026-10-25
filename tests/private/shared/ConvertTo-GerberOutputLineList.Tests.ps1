BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'ConvertTo-GerberOutputLineList' {
    It 'converts mixed output values to strings and drops nulls' {
        $result = ConvertTo-GerberOutputLineList -Output @('a', 1, $null)

        $result | Should -Be @('a', '1')
    }
}
