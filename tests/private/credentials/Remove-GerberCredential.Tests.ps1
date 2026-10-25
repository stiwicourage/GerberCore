BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Remove-GerberCredential' -Tag 'CredentialServiceNamespace' {
    It 'returns true when the provider removes the credential' -ForEach @(
        @{ ServiceName = 'credentials' }
        @{ ServiceName = 'gerber://credentials' }
    ) {
        $store = [pscustomobject]@{}
        $store | Add-Member -MemberType ScriptMethod -Name Remove -Value {
            param($service)
            $script:removedService = $service
            return $true
        }
        Mock Get-GerberCredentialStore { $store }
        Mock Resolve-GerberCredentialServiceName { $ServiceName }

        Remove-GerberCredential -Identifier 'gerber:ado:example:pat' | Should -BeTrue
        $script:removedService | Should -Be $ServiceName
    }

    It 'returns false when the credential was already missing' {
        $store = [pscustomobject]@{}
        $store | Add-Member -MemberType ScriptMethod -Name Remove -Value { $false }
        Mock Get-GerberCredentialStore { $store }

        Remove-GerberCredential -Identifier 'gerber:ado:missing:pat' | Should -BeFalse
    }
}
