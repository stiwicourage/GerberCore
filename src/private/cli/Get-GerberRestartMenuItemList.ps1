function Get-GerberRestartMenuItemList {
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][string]$Subject,
        [string]$HostName = $Host.Name
    )
    $items = @(
        [pscustomobject]@{ Number = 1; Value = 'continue'; Label = 'Continue with current version'; PreviewText = "Keep using this session. Restart PowerShell later to use $Subject." }
        [pscustomobject]@{ Number = 2; Value = 'exit'; Label = 'Exit Gerber'; PreviewText = 'Return to PowerShell. Gerber stays loaded there; restart PowerShell yourself.' }
    )
    if (Test-GerberPowerShellHostExitSupported -HostName $HostName) {
        $items += [pscustomobject]@{ Number = 3; Value = 'exit-host'; Label = 'Exit Gerber and PowerShell'; PreviewText = 'Close this PowerShell session. Start PowerShell again, then run gerber.' }
    }
    $items
}
