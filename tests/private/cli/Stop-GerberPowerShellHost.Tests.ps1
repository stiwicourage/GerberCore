BeforeAll {
    $script:source = Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))) 'src/private/cli/Stop-GerberPowerShellHost.ps1'
    $script:pwsh = (Get-Process -Id $PID).Path
}

Describe 'Stop-GerberPowerShellHost' -Tag 'RestartHost' {
    It 'ends a PowerShell process that would otherwise stay open after the calling function' {
        $command = ". '$($script:source)'; function Invoke-Caller { Stop-GerberPowerShellHost; 'STILL-RUNNING' }; Invoke-Caller; 'STILL-RUNNING'"
        $output = & $script:pwsh -NoLogo -NoProfile -NoExit -NonInteractive -Command $command 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $output | Should -Not -Match 'STILL-RUNNING'
    }
}
