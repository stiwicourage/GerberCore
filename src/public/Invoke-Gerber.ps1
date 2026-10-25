function Invoke-Gerber {
    [Alias('gerber')]
    [CmdletBinding()]
    param()

    Clear-GerberCommandRegistry
    $null = Initialize-GerberCommandRegistry
    try {
        $script:GerberStartupUpdateState = Invoke-GerberStartupUpdateCheck
        Show-GerberMenu
    } finally {
        Remove-Variable -Name GerberStartupUpdateState -Scope Script -ErrorAction SilentlyContinue
        Clear-GerberCommandRegistry
    }
}
