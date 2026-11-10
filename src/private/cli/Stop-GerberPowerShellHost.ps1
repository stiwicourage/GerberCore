function Stop-GerberPowerShellHost {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Only called after the user explicitly chose to close PowerShell.')]
    param()
    exit 0
}
