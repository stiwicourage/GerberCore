BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberCredentialIdentifier' {
    It 'creates a stable lower-case identifier with escaped segments' {
        Get-GerberCredentialIdentifier -Scope 'ADO' -SegmentList @('Main Profile', 'PAT') |
            Should -Be 'gerber:ado:main%20profile:pat'
    }

    It 'rejects empty scopes and segments' {
        { Get-GerberCredentialIdentifier -Scope ' ' -SegmentList @('name') } |
            Should -Throw '*credential scope must not be empty*'
        { Get-GerberCredentialIdentifier -Scope 'plugin' -SegmentList @('name', ' ') } |
            Should -Throw '*credential path segments must not be empty*'
    }
}
