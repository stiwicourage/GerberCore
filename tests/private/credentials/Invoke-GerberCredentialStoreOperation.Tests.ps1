BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Invoke-GerberCredentialStoreOperation' {
    It 'returns the provider operation result' {
        Invoke-GerberCredentialStoreOperation -Action 'read a credential' -Operation { 'value' } |
            Should -Be 'value'
    }

    It 'reports unavailable native storage without exposing sensitive values' {
        $secret = 'do-not-expose-this-value'
        $errorText = $null
        try {
            Invoke-GerberCredentialStoreOperation -Action 'store a credential' -Operation {
                throw "Devlooped CredentialManager failed while handling $secret"
            }
        } catch {
            $errorText = $_.Exception.ToString()
        }

        $errorText | Should -Match 'secure credential storage'
        $errorText | Should -Not -Match 'Devlooped'
        $errorText | Should -Not -Match 'CredentialManager'
        $errorText | Should -Not -Match $secret
    }
}
