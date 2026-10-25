BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoRetryDelay' {
    It 'increases the delay with each attempt' {
        (Get-GerberAdoRetryDelay -AttemptNumber 1) | Should -Be 1
        (Get-GerberAdoRetryDelay -AttemptNumber 2) | Should -Be 2
    }
}
