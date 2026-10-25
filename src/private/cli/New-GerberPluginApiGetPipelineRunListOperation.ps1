function New-GerberPluginApiGetPipelineRunListOperation {
        [OutputType([scriptblock])]
        [CmdletBinding(SupportsShouldProcess)]
        param()
        $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiGetPipelineRunListOperation', 'Invoke')

        return Get-GerberModuleBoundScriptBlock -ScriptBlock {
            param(
                [pscustomobject]$RunListRequest
            )

            $resolvedRequest = Set-GerberPluginApiRequestConfiguration -Request $RunListRequest
            return @(Get-GerberAdoPipelineRunList -RunListRequest $resolvedRequest)
        }
    }
