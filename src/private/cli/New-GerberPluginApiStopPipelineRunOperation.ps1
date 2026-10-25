function New-GerberPluginApiStopPipelineRunOperation {
        [OutputType([scriptblock])]
        [CmdletBinding(SupportsShouldProcess)]
        param()
        $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiStopPipelineRunOperation', 'Invoke')

        return Get-GerberModuleBoundScriptBlock -ScriptBlock {
            param(
                [pscustomobject]$Connection,
                [int]$BuildId
            )

            $requestContext = Get-GerberPluginApiAdoRequestContext -Connection $Connection -RequireAuthentication
            Stop-GerberAdoPipelineRun `
                -Configuration $requestContext.Configuration `
                -Pat $requestContext.Pat `
                -BuildId $BuildId
        }
    }
