function New-GerberPluginApiGetWorkItemIdFromUrlOperation {
    [OutputType([scriptblock])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiGetWorkItemIdFromUrlOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param(
            [string]$WorkItemUrl
        )

        return Get-GerberAdoWorkItemIdFromUrl -WorkItemUrl $WorkItemUrl
    }
}
