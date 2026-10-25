BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberCredentialStore' {
    BeforeEach {
        Remove-Variable -Name GerberCredentialStore -Scope Script -ErrorAction SilentlyContinue
    }

    It 'creates the provider lazily and reuses it for the session' {
        $provider = [pscustomobject]@{ Name = 'provider' }
        Mock Initialize-GerberCredentialStore { $provider }

        $first = Get-GerberCredentialStore
        $second = Get-GerberCredentialStore

        [object]::ReferenceEquals($first, $provider) | Should -BeTrue
        [object]::ReferenceEquals($second, $provider) | Should -BeTrue
        Should -Invoke Initialize-GerberCredentialStore -Times 1
    }

    It 'does not initialize the provider merely because source files were loaded' {
        Get-Variable -Name GerberCredentialStore -Scope Script -ErrorAction SilentlyContinue |
            Should -BeNullOrEmpty
    }

    It 'sanitizes initialization failures without exposing provider branding' {
        Mock Initialize-GerberCredentialStore {
            throw [System.InvalidOperationException]::new('Devlooped.CredentialManager 2.6.0.0 is already loaded.')
        }

        $errorText = $null
        try {
            Get-GerberCredentialStore | Out-Null
        } catch {
            $errorText = $_.Exception.ToString()
        }

        $errorText | Should -Match 'secure credential storage'
        $errorText | Should -Not -Match 'Devlooped'
    }

    It 'accepts the packaged dependency version when it is already loaded' {
        {
            Assert-GerberLoadedAssemblyVersion `
                -AssemblyName 'Devlooped.CredentialManager' `
                -ExpectedVersion ([version]'2.7.0.0') `
                -LoadedAssemblyNameList @(
                    [Reflection.AssemblyName]::new('Devlooped.CredentialManager, Version=2.7.0.0')
                )
        } | Should -Not -Throw
    }

    It 'rejects a conflicting dependency version already loaded in the session' {
        {
            Assert-GerberLoadedAssemblyVersion `
                -AssemblyName 'Devlooped.CredentialManager' `
                -ExpectedVersion ([version]'2.7.0.0') `
                -LoadedAssemblyNameList @(
                    [Reflection.AssemblyName]::new('Devlooped.CredentialManager, Version=2.6.0.0')
                )
        } | Should -Throw '*requires Devlooped.CredentialManager 2.7.0.0*version 2.6.0.0 is already loaded*'
    }
}
