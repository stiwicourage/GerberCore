BeforeAll {
    . (Join-Path $PSScriptRoot '../../../src/private/credentials/Resolve-GerberCredentialServiceName.ps1')
}

Describe 'Resolve-GerberCredentialServiceName' -Tag 'CredentialServiceNamespace' {
    It 'uses an absolute service URI required by the Windows provider' {
        Resolve-GerberCredentialServiceName -Windows $true | Should -Be 'gerber://credentials'
    }

    It 'preserves the existing macOS and Linux credential service' {
        Resolve-GerberCredentialServiceName -Windows $false | Should -Be 'credentials'
    }
}
