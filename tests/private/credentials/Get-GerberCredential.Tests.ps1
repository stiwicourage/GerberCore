BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberCredential' -Tag 'CredentialServiceNamespace' {
    It 'retrieves the credential secret from the Gerber service' -ForEach @(
        @{ ServiceName = 'credentials' }
        @{ ServiceName = 'gerber://credentials' }
    ) {
        $store = [pscustomobject]@{}
        $store | Add-Member -MemberType ScriptMethod -Name Get -Value {
            param($service, $account)
            [pscustomobject]@{ Account = $account; Password = "$service-secret" }
        }
        Mock Get-GerberCredentialStore { $store }
        Mock Resolve-GerberCredentialServiceName { $ServiceName }

        Get-GerberCredential -Identifier 'Gerber:ADO:Example:PAT' | Should -Be "$ServiceName-secret"
    }

    It 'returns null when the credential does not exist' {
        $store = [pscustomobject]@{}
        $store | Add-Member -MemberType ScriptMethod -Name Get -Value { $null }
        Mock Get-GerberCredentialStore { $store }

        Get-GerberCredential -Identifier 'gerber:ado:missing:pat' | Should -BeNullOrEmpty
    }
}
