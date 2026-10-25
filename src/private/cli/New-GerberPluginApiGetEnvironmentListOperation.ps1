function New-GerberPluginApiGetEnvironmentListOperation {
    [OutputType([scriptblock])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiGetEnvironmentListOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param(
            [pscustomobject]$Connection
        )

        $requestContext = Get-GerberPluginApiAdoRequestContext -Connection $Connection -RequireAuthentication
        return @(Get-GerberAdoEnvironmentList -Configuration $requestContext.Configuration -Pat $requestContext.Pat)
    }
}
