BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Write-GerberConsoleLineBreak' {
    It 'writes a line break without throwing' {
        { Write-GerberConsoleLineBreak } | Should -Not -Throw
    }
}
