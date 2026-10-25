BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'ConvertFrom-GerberBase64' {
    It 'decodes UTF-8 text from Base64' {
        $result = ConvertFrom-GerberBase64 -Value 'R2VyYmVy'

        $result | Should -Be 'Gerber'
    }

    It 'ignores surrounding whitespace and line breaks before decoding' {
        $result = ConvertFrom-GerberBase64 -Value " `nR2Vy`nYmVy `n"

        $result | Should -Be 'Gerber'
    }

    It 'rejects invalid Base64 text with a Gerber-owned message' {
        { ConvertFrom-GerberBase64 -Value '***' } | Should -Throw 'That value is not valid Base64. Remove extra characters and try again.'
    }

    It 'requires a non-empty Base64 value' {
        { ConvertFrom-GerberBase64 -Value '   ' } | Should -Throw 'Enter a Base64 value to decode.'
    }

    It 'rejects Base64 that does not decode to UTF-8 text' {
        $value = [Convert]::ToBase64String([byte[]]@(0xFF, 0xFF))

        { ConvertFrom-GerberBase64 -Value $value } | Should -Throw 'That Base64 value does not decode to UTF-8 text.'
    }
}
