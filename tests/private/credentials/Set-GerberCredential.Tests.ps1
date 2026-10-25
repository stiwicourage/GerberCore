BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Set-GerberCredential' -Tag 'CredentialServiceNamespace' {
    It 'creates or updates a credential without returning the secret' -ForEach @(
        @{ ServiceName = 'credentials' }
        @{ ServiceName = 'gerber://credentials' }
    ) {
        $script:setArguments = $null
        $store = [pscustomobject]@{}
        $store | Add-Member -MemberType ScriptMethod -Name AddOrUpdate -Value {
            param($service, $account, $secret)
            $script:setArguments = @($service, $account, $secret)
        }
        Mock Get-GerberCredentialStore { $store }
        Mock Resolve-GerberCredentialServiceName { $ServiceName }

        $result = Set-GerberCredential -Identifier 'Gerber:ADO:Example:PAT' -Secret 'sensitive'

        $result.Identifier | Should -Be 'gerber:ado:example:pat'
        $result.PSObject.Properties.Name | Should -Be @('Identifier')
        $result.PSObject.Properties.Name | Should -Not -Contain 'Secret'
        $script:setArguments | Should -Be @($ServiceName, 'gerber:ado:example:pat', 'sensitive')
    }
}
