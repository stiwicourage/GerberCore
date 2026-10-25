function New-GerberPluginApiRemoveBuildTagOperation {
        [OutputType([scriptblock])]
        [CmdletBinding(SupportsShouldProcess)]
        param()
        $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiRemoveBuildTagOperation', 'Invoke')

        return Get-GerberModuleBoundScriptBlock -ScriptBlock {
            param(
                [pscustomobject]$Connection,
                [int]$BuildId,
                [string]$Tag
            )

            $requestContext = Get-GerberPluginApiAdoRequestContext -Connection $Connection -RequireAuthentication
            Remove-GerberAdoBuildTag `
                -Configuration $requestContext.Configuration `
                -Pat $requestContext.Pat `
                -BuildId $BuildId `
                -Tag $Tag
        }
    }
