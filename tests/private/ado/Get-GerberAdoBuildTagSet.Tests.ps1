BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoBuildTagSet' {
    It 'returns a case-insensitive set of non-empty build tags' {
        Mock Get-GerberAdoBuildTagList { @('Juni release 2026', 'keep-me', '', 'KEEP-ME') }

        $result = Get-GerberAdoBuildTagSet `
            -Configuration ([pscustomobject]@{}) `
            -Pat 'pat' `
            -BuildId 9001

        $result.Contains('juni release 2026') | Should -BeTrue
        $result.Contains('KEEP-ME') | Should -BeTrue
        $result.Count | Should -Be 2
    }
}
