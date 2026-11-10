function Complete-GerberRestartSelection {
    param([string]$Selection, [string]$Guidance)
    Write-GerberPromptTrace -EventName 'update-restart-choice' -Data @{ Selection = $Selection }
    if ($Selection -eq 'exit-host') {
        Write-GerberScreenLine -Text 'Closing PowerShell. Start PowerShell again, then run gerber.'
        Stop-GerberPowerShellHost
        return $true
    }
    if ($Selection -eq 'exit') {
        Write-GerberScreenLine -Text "Exiting Gerber. $Guidance"
        return $true
    }
}
