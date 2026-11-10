BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberRestartGuidance' -Tag 'RestartHost' {
    It 'explains that exiting Gerber alone keeps the old module and points to closing the console session' {
        $text = Get-GerberRestartGuidance -Subject 'installed Core' -HostName 'ConsoleHost'
        $text | Should -Match 'Exiting Gerber does not restart PowerShell'
        $text | Should -Match "Exit Gerber and PowerShell"
        $text | Should -Match 'to use installed Core'
        $text | Should -Match 'has not reloaded'
    }

    It 'tells users of <HostName> to restart the session from the host itself' -ForEach @(
        @{ HostName = 'Visual Studio Code Host' }
        @{ HostName = 'Windows PowerShell ISE Host' }
    ) {
        $text = Get-GerberRestartGuidance -Subject 'installed components' -HostName $HostName
        $text | Should -Match 'Exiting Gerber does not restart PowerShell'
        $text | Should -Match ([regex]::Escape($HostName))
        $text | Should -Match 'restart the PowerShell session from the host'
        $text | Should -Not -Match 'Exit Gerber and PowerShell'
    }
}
