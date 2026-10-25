function New-GerberPluginApiGetPendingApprovalListOperation {
    [OutputType([scriptblock])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiGetPendingApprovalListOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param(
            [pscustomobject]$Connection,
            [int]$EnvironmentId
        )

        $requestContext = Get-GerberPluginApiAdoRequestContext -Connection $Connection -RequireAuthentication
        return @(Get-GerberAdoPendingApprovalList `
                -Configuration $requestContext.Configuration `
                -Pat $requestContext.Pat `
                -EnvironmentId $EnvironmentId)
    }
}
