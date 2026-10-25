BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Use-GerberCredentialStore' {
    It 'checks native storage only when explicitly requested' {
        Mock Get-GerberCredentialInfo { @() }

        Use-GerberCredentialStore | Should -BeTrue

        Should -Invoke Get-GerberCredentialInfo -Times 1
    }
}
