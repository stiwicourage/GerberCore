BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Test-GerberPowerShellHostExitSupported' -Tag 'RestartHost' {
    It 'allows closing a console host session' {
        Test-GerberPowerShellHostExitSupported -HostName 'ConsoleHost' | Should -BeTrue
    }

    It 'does not close embedded or remote hosts that restart sessions themselves' -ForEach @(
        @{ HostName = 'Visual Studio Code Host' }
        @{ HostName = 'Windows PowerShell ISE Host' }
        @{ HostName = 'ServerRemoteHost' }
        @{ HostName = 'Default Host' }
        @{ HostName = '' }
    ) {
        Test-GerberPowerShellHostExitSupported -HostName $HostName | Should -BeFalse
    }

    It 'uses the current host by default' {
        Test-GerberPowerShellHostExitSupported | Should -Be ($Host.Name -ceq 'ConsoleHost')
    }
}
