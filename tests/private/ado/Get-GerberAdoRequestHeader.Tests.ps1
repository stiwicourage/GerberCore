BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoRequestHeader' {
    It 'returns a basic authorization header from a PAT' {
        $result = Get-GerberAdoRequestHeader -Pat 'pat-value'

        $result.Authorization | Should -Be 'Basic OnBhdC12YWx1ZQ=='
        $result['User-Agent'] | Should -Be 'Gerber'
    }
}
