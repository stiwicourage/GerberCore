function New-GerberPluginApiGetBuildTagListOperation {
        [OutputType([scriptblock])]
        [CmdletBinding(SupportsShouldProcess)]
        param()
        $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiGetBuildTagListOperation', 'Invoke')

        return Get-GerberModuleBoundScriptBlock -ScriptBlock {
            param(
                [pscustomobject]$Connection,
                [int]$BuildId
            )

            $requestContext = Get-GerberPluginApiAdoRequestContext -Connection $Connection -RequireAuthentication
            return @(Get-GerberAdoBuildTagList `
                    -Configuration $requestContext.Configuration `
                    -Pat $requestContext.Pat `
                    -BuildId $BuildId)
        }
    }
