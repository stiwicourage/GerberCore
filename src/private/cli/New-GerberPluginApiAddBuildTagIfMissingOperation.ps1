function New-GerberPluginApiAddBuildTagIfMissingOperation {
        [OutputType([scriptblock])]
        [CmdletBinding(SupportsShouldProcess)]
        param()
        $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiAddBuildTagIfMissingOperation', 'Invoke')

        return Get-GerberModuleBoundScriptBlock -ScriptBlock {
            param(
                [pscustomobject]$Connection,
                [int]$BuildId,
                [string]$Tag
            )

            $requestContext = Get-GerberPluginApiAdoRequestContext -Connection $Connection -RequireAuthentication
            return Add-GerberAdoBuildTagIfMissing `
                -Configuration $requestContext.Configuration `
                -Pat $requestContext.Pat `
                -BuildId $BuildId `
                -Tag $Tag
        }
    }
