BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberCredentialInfo' -Tag 'CredentialServiceNamespace' {
    It 'enumerates only normalized identifiers from the Gerber credential service' -ForEach @(
        @{ ServiceName = 'credentials' }
        @{ ServiceName = 'gerber://credentials' }
    ) {
        $store = [pscustomobject]@{}
        $store | Add-Member -MemberType ScriptMethod -Name GetAccounts -Value {
            param($service)
            $script:listedService = $service
            @('gerber:user:z', 'Gerber:ADO:Example:PAT')
        }
        Mock Get-GerberCredentialStore { $store }
        Mock Resolve-GerberCredentialServiceName { $ServiceName }

        $result = @(Get-GerberCredentialInfo)

        $result.Identifier | Should -Be @('gerber:ado:example:pat', 'gerber:user:z')
        $result[0].PSObject.Properties.Name | Should -Be @('Identifier')
        $result[0].PSObject.Properties.Name | Should -Not -Contain 'Secret'
        $script:listedService | Should -Be $ServiceName
    }
}
