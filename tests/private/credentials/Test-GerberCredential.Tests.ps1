BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Test-GerberCredential' -Tag 'CredentialServiceNamespace' {
    It 'checks account identifiers without retrieving the secret value' -ForEach @(
        @{ ServiceName = 'credentials' }
        @{ ServiceName = 'gerber://credentials' }
    ) {
        $store = [pscustomobject]@{}
        $store | Add-Member -MemberType ScriptMethod -Name GetAccounts -Value {
            param($service)
            $script:checkedService = $service
            @('gerber:user:test:empty')
        }
        $store | Add-Member -MemberType ScriptMethod -Name Get -Value {
            throw 'Existence checks must not retrieve credential values.'
        }
        Mock Get-GerberCredentialStore { $store }
        Mock Resolve-GerberCredentialServiceName { $ServiceName }

        Test-GerberCredential -Identifier 'gerber:user:test:empty' | Should -BeTrue
        $script:checkedService | Should -Be $ServiceName
        Test-GerberCredential -Identifier 'gerber:user:test:missing' | Should -BeFalse
        $script:checkedService | Should -Be $ServiceName
    }
}
