function New-GerberPluginApiGetWorkItemFieldMapOperation {
        [OutputType([scriptblock])]
        [CmdletBinding(SupportsShouldProcess)]
        param()
        $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiGetWorkItemFieldMapOperation', 'Invoke')

        return Get-GerberModuleBoundScriptBlock -ScriptBlock {
            param(
                [pscustomobject]$WorkItemRequest
            )

            $resolvedRequest = Set-GerberPluginApiRequestConfiguration -Request $WorkItemRequest
            return Get-GerberAdoWorkItemFieldMap -WorkItemRequest $resolvedRequest
        }
    }
