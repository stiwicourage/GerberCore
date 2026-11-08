function Show-GerberCoreUpdateRestartChoice {
    param([string]$Text)
    $guidance = 'Exiting Gerber does not restart PowerShell. Restart PowerShell, then run gerber to use the installed Core. Continuing uses the current version; Core has not reloaded.'
    $script:GerberStartupUpdateState = [pscustomobject]@{ Status = 'RestartRequired'; Message = $guidance }
    $selection = Read-GerberCoreUpdateRestartSelection -Text "$Text`n`n$guidance"
    Write-GerberPromptTrace -EventName 'update-restart-choice' -Data @{ Selection = $selection }
    if ($selection -eq 'exit') {
        Write-GerberScreenLine -Text "Exiting Gerber. $guidance"
        return $true
    }
}

function Read-GerberCoreUpdateRestartSelection {
    param([string]$Text)
    $items = @(
        [pscustomobject]@{ Number = 1; Value = 'continue'; Label = 'Continue with current version'; PreviewText = 'Keep using this session. Restart PowerShell later to use the installed Core.' }
        [pscustomobject]@{ Number = 2; Value = 'exit'; Label = 'Exit Gerber'; PreviewText = 'Return to PowerShell. Restart PowerShell yourself, then run gerber.' }
    )
    try {
        return Read-GerberNumberedMenuPrompt -Prompt 'Core update next step (Esc to continue)' `
            -ScreenTitle '/update list' -ScreenText $Text -MenuItemList $items
    } catch {
        if (-not (Test-GerberMenuEscapeException -Exception $_.Exception)) { throw }
        return 'continue'
    }
}
