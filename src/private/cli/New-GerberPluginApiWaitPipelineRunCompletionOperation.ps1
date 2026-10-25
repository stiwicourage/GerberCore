function New-GerberPluginApiWaitPipelineRunCompletionOperation {
        [OutputType([scriptblock])]
        [CmdletBinding(SupportsShouldProcess)]
        param()
        $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiWaitPipelineRunCompletionOperation', 'Invoke')

        return Get-GerberModuleBoundScriptBlock -ScriptBlock {
            param(
                [pscustomobject]$RunWaitRequest
            )

            $resolvedRequest = Set-GerberPluginApiRequestConfiguration -Request $RunWaitRequest
            return Wait-GerberAdoPipelineRunCompletion -RunWaitRequest $resolvedRequest
        }
    }
