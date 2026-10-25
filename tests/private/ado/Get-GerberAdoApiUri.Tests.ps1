BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoApiUri' {
    It 'escapes and appends the query parameters to the base URI' {
        $result = Get-GerberAdoApiUri `
            -BaseUri ([uri]'https://ado.example.com/Collection/_apis/git/repositories') `
            -QueryParameterMap ([ordered]@{ 'api-version' = '7.1'; 'search text' = 'a b' })

        $result.AbsoluteUri | Should -BeLike 'https://ado.example.com/Collection/_apis/git/repositories?*'
        $result.AbsoluteUri | Should -Match 'api-version=7\.1'
        $result.AbsoluteUri | Should -Match 'search%20text=a%20b'
    }
}
