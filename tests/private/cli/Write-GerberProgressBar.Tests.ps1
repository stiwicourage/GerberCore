BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Write-GerberProgressBar' {
    It 'does not throw when Current is less than Total' {
        { Write-GerberProgressBar -Current 3 -Total 10 } | Should -Not -Throw
    }

    It 'does not throw when Current equals Total' {
        { Write-GerberProgressBar -Current 10 -Total 10 } | Should -Not -Throw
    }

    It 'does not throw when Current is 0' {
        { Write-GerberProgressBar -Current 0 -Total 10 } | Should -Not -Throw
    }

    It 'does not throw when Total is 0' {
        { Write-GerberProgressBar -Current 0 -Total 0 } | Should -Not -Throw
    }

    It 'does not throw when Current exceeds Total' {
        { Write-GerberProgressBar -Current 12 -Total 10 } | Should -Not -Throw
    }

    It 'does not throw when Prefix is supplied' {
        { Write-GerberProgressBar -Current 3 -Total 10 -Prefix 'Loading...' } | Should -Not -Throw
    }

    It 'does not throw when Prefix is an empty string' {
        { Write-GerberProgressBar -Current 3 -Total 10 -Prefix '' } | Should -Not -Throw
    }

    It 'does not throw on a subsequent update where cursor-up is applied' {
        { Write-GerberProgressBar -Current 2 -Total 10 } | Should -Not -Throw
    }

    It 'does not throw when asked to overwrite a previously rendered placeholder bar' {
        { Write-GerberProgressBar -Current 1 -Total 10 -OverwritePreviousRender } | Should -Not -Throw
    }
}
