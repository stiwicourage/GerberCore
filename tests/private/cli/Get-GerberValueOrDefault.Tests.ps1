BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberValueOrDefault' {
    It 'returns the default value for null, empty, or whitespace input' {
        (Get-GerberValueOrDefault -Value $null -DefaultValue 'fallback') | Should -Be 'fallback'
        (Get-GerberValueOrDefault -Value '' -DefaultValue 'fallback') | Should -Be 'fallback'
        (Get-GerberValueOrDefault -Value '   ' -DefaultValue 'fallback') | Should -Be 'fallback'
    }

    It 'returns the provided value when it is not blank' {
        (Get-GerberValueOrDefault -Value 'actual' -DefaultValue 'fallback') | Should -Be 'actual'
    }
}
