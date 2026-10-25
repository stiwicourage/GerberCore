BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'ConvertTo-GerberBase64' {
    It 'encodes UTF-8 text as Base64' {
        $result = ConvertTo-GerberBase64 -Value 'Gerber'

        $result | Should -Be 'R2VyYmVy'
    }

    It 'encodes an empty string as an empty Base64 payload' {
        $result = ConvertTo-GerberBase64 -Value ''

        $result | Should -Be ''
    }
}
