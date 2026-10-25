function New-GerberPluginApiReadConfirmationPromptOperation {
    [OutputType([scriptblock])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiReadConfirmationPromptOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param(
            [string]$Prompt,
            [string]$ScreenTitle,
            [string]$ScreenText,
            [pscustomobject]$PromptOptionSet
        )

        return Read-GerberConfirmationPrompt `
            -Prompt $Prompt `
            -ScreenTitle $ScreenTitle `
            -ScreenText $ScreenText `
            -PromptOptionSet $PromptOptionSet
    }
}
