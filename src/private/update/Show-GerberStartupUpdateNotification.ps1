function Show-GerberStartupUpdateNotification {
    param()
    $state = Get-Variable -Name GerberStartupUpdateState -Scope Script -ValueOnly -ErrorAction SilentlyContinue
    if ($null -eq $state) { return }
    if ($state.Status -eq 'Available') {
        Write-GerberScreenLine -Text "Gerber Core $($state.Available) is available. Run /update list to review."
    }
}
