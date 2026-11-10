function Show-GerberCoreUpdateRestartChoice {
    param([string]$Text)
    $guidance = Get-GerberRestartGuidance -Subject 'the installed Core'
    $script:GerberStartupUpdateState = [pscustomobject]@{ Status = 'RestartRequired'; Message = $guidance }
    $selection = Read-GerberCoreUpdateRestartSelection -Text "$Text`n`n$guidance"
    Complete-GerberRestartSelection -Selection $selection -Guidance $guidance
}

function Read-GerberCoreUpdateRestartSelection {
    param([string]$Text)
    $items = @(Get-GerberRestartMenuItemList -Subject 'the installed Core')
    try {
        return Read-GerberNumberedMenuPrompt -Prompt 'Core update next step (Esc to continue)' `
            -ScreenTitle '/update list' -ScreenText $Text -MenuItemList $items
    } catch {
        if (-not (Test-GerberMenuEscapeException -Exception $_.Exception)) { throw }
        return 'continue'
    }
}
