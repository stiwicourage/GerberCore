function New-GerberPluginApiReadSecretTextOperation {
    [OutputType([scriptblock])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiReadSecretTextOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param(
            [string]$Prompt
        )

        return Read-GerberPluginApiSecretText -Prompt $Prompt
    }
}
