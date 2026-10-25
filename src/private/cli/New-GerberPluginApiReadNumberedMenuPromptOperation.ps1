function New-GerberPluginApiReadNumberedMenuPromptOperation {
    [OutputType([scriptblock])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiReadNumberedMenuPromptOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param(
            [string]$Prompt,
            [string]$ScreenTitle,
            [string]$ScreenText,
            [object[]]$MenuItemList
        )

        return Read-GerberNumberedMenuPrompt `
            -Prompt $Prompt `
            -ScreenTitle $ScreenTitle `
            -ScreenText $ScreenText `
            -MenuItemList @($MenuItemList)
    }
}
