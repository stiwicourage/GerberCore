BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoCredentialIdentifier' {
    It 'derives a stable PAT identifier per case-insensitive profile name' {
        Get-GerberAdoCredentialIdentifier -ProfileName 'EXAMPLE' |
            Should -Be 'gerber:ado:example:pat'
        Get-GerberAdoCredentialIdentifier -ProfileName 'Main Profile' |
            Should -Be 'gerber:ado:main%20profile:pat'
    }
}
