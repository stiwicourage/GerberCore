function New-GerberPluginApiWaitForContinueOperation {
    [OutputType([scriptblock])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiWaitForContinueOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param()

        return Wait-GerberPluginApiContinue
    }
}
