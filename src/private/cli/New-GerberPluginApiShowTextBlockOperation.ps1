function New-GerberPluginApiShowTextBlockOperation {
    [OutputType([scriptblock])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiShowTextBlockOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param(
            [string]$Title,
            [AllowEmptyString()]
            [string]$Text
        )

        Show-GerberPluginApiTextBlock -Title $Title -Text $Text
    }
}
