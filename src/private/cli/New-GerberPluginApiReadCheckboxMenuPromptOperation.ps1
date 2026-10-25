function New-GerberPluginApiReadCheckboxMenuPromptOperation {
    [OutputType([scriptblock])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiReadCheckboxMenuPromptOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param(
            [pscustomobject]$PromptRequest
        )

        return Read-GerberCheckboxMenuPrompt -PromptRequest $PromptRequest
    }
}
