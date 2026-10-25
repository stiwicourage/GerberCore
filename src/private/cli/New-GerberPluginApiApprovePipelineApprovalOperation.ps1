function New-GerberPluginApiApprovePipelineApprovalOperation {
        [OutputType([scriptblock])]
        [CmdletBinding(SupportsShouldProcess)]
        param()
        $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiApprovePipelineApprovalOperation', 'Invoke')

        return Get-GerberModuleBoundScriptBlock -ScriptBlock {
            param(
                [pscustomobject]$Connection,
                [string]$ApprovalId,
                [string]$Comment
            )

            $requestContext = Get-GerberPluginApiAdoRequestContext -Connection $Connection -RequireAuthentication
            Approve-GerberAdoPipelineApproval `
                -Configuration $requestContext.Configuration `
                -Pat $requestContext.Pat `
                -ApprovalId $ApprovalId `
                -Comment $Comment
        }
    }
