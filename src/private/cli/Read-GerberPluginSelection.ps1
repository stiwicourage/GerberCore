function Read-GerberPluginSelection {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandTitle,

        [Parameter(Mandatory)]
        [string]$EmptyText,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$PluginList
    )

    if ($PluginList.Count -eq 0) {
        Show-GerberTextBlock -Title $CommandTitle -Text $EmptyText
        Wait-GerberContinue
        return $null
    }

    $menuItemList = @(
        for ($index = 0; $index -lt $PluginList.Count; $index++) {
            [pscustomobject]@{
                Number      = $index + 1
                Label       = "$($PluginList[$index].DisplayName) ($($PluginList[$index].Version))"
                Value       = $PluginList[$index].Guid
                PreviewText = "Approval: $($PluginList[$index].ApprovalStatus), State: $($PluginList[$index].State)"
            }
        }
    )

    try {
        $selectedGuid = Read-GerberNumberedMenuPrompt `
            -Prompt 'Select plugin (Esc to go back)' `
            -ScreenTitle $CommandTitle `
            -ScreenText '' `
            -MenuItemList $menuItemList
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) {
            return $null
        }

        throw
    }

    return @($PluginList | Where-Object { $_.Guid -ieq $selectedGuid })[0]
}
