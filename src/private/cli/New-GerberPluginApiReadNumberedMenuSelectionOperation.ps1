function New-GerberPluginApiReadNumberedMenuSelectionOperation {
    [OutputType([scriptblock])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiReadNumberedMenuSelectionOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param(
            [string]$Prompt,
            [string]$ScreenTitle,
            [string]$ScreenText,
            [object[]]$MenuItemList
        )

        try {
            return Read-GerberNumberedMenuPrompt `
                -Prompt $Prompt `
                -ScreenTitle $ScreenTitle `
                -ScreenText $ScreenText `
                -MenuItemList @($MenuItemList)
        } catch {
            if (Test-GerberMenuEscapeException -Exception $_.Exception) {
                return $null
            }

            throw
        }
    }
}
