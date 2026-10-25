function New-GerberPluginApiStartPipelineRunOperation {
        [OutputType([scriptblock])]
        [CmdletBinding(SupportsShouldProcess)]
        param()
        $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiStartPipelineRunOperation', 'Invoke')

        return Get-GerberModuleBoundScriptBlock -ScriptBlock {
            param(
                [pscustomobject]$RunRequest
            )

            $resolvedRequest = Set-GerberPluginApiRequestConfiguration -Request $RunRequest
            return Start-GerberAdoPipelineRun -RunRequest $resolvedRequest
        }
    }
