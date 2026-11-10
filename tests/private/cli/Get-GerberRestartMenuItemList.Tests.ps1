BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberRestartMenuItemList' -Tag 'RestartHost' {
    It 'offers closing PowerShell as third choice on a console host and keeps Continue as default' {
        $items = @(Get-GerberRestartMenuItemList -Subject 'Core' -HostName 'ConsoleHost')
        $items.Value | Should -Be @('continue', 'exit', 'exit-host')
        $items.Number | Should -Be @(1, 2, 3)
        $items[2].Label | Should -Be 'Exit Gerber and PowerShell'
        $items[1].PreviewText | Should -Match 'Return to PowerShell'
    }

    It 'does not offer closing PowerShell on <HostName>' -ForEach @(
        @{ HostName = 'Visual Studio Code Host' }
        @{ HostName = 'Windows PowerShell ISE Host' }
        @{ HostName = 'ServerRemoteHost' }
    ) {
        $items = @(Get-GerberRestartMenuItemList -Subject 'components' -HostName $HostName)
        $items.Value | Should -Be @('continue', 'exit')
    }
}
