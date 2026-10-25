function New-GerberPluginApiResolvePipelineDefinitionFromUrlOperation {
    [OutputType([scriptblock])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiResolvePipelineDefinitionFromUrlOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param(
            [pscustomobject]$Connection,
            [uri]$PipelineUrl
        )

        $requestContext = Get-GerberPluginApiAdoRequestContext -Connection $Connection -RequireAuthentication
        return Resolve-GerberAdoPipelineDefinitionFromUrl `
            -Configuration $requestContext.Configuration `
            -Pat $requestContext.Pat `
            -PipelineUrl $PipelineUrl
    }
}
