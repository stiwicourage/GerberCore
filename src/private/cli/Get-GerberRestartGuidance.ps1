function Get-GerberRestartGuidance {
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$Subject,
        [string]$HostName = $Host.Name
    )
    $text = "Exiting Gerber does not restart PowerShell. Restart PowerShell, then run gerber to use $Subject."
    if (Test-GerberPowerShellHostExitSupported -HostName $HostName) {
        return "$text Choose 'Exit Gerber and PowerShell' to close this session. Continuing keeps the current session; it has not reloaded."
    }
    "$text This host ($HostName) cannot be closed from Gerber; restart the PowerShell session from the host itself. Continuing keeps the current session; it has not reloaded."
}
