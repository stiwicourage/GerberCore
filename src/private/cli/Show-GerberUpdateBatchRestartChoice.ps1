function Show-GerberUpdateBatchRestartChoice {
    param([string]$Text)
    $guidance = Get-GerberRestartGuidance -Subject 'installed components'
    $script:GerberStartupUpdateState = [pscustomobject]@{
        Status = 'RestartRequired'; Message = $guidance
    }
    $selection = Read-GerberUpdateBatchRestartSelection -Text "$Text`n`n$guidance"
    Complete-GerberRestartSelection -Selection $selection -Guidance $guidance
}

function Read-GerberUpdateBatchRestartSelection {
    param([string]$Text)
    $items = @(Get-GerberRestartMenuItemList -Subject 'installed components')
    try {
        Read-GerberNumberedMenuPrompt -Prompt 'Update next step (Esc to continue)' -ScreenTitle '/update list' -ScreenText $Text -MenuItemList $items
    } catch {
        if (-not (Test-GerberMenuEscapeException -Exception $_.Exception)) {
            throw
        }
        'continue'
    }
}
