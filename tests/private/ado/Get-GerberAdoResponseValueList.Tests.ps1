BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoResponseValueList' {
    It 'returns wrapped value array when response has value property' {
        $response = [pscustomobject]@{
            value = @('item1', 'item2', 'item3')
        }

        $result = Get-GerberAdoResponseValueList -Response $response

        $result.Count | Should -Be 3
        $result[0] | Should -Be 'item1'
    }
}
