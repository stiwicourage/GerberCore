function New-GerberPluginApiGetBuildRunUrlOperation {
        [OutputType([scriptblock])]
        [CmdletBinding(SupportsShouldProcess)]
        param()
        $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiGetBuildRunUrlOperation', 'Invoke')

        return Get-GerberModuleBoundScriptBlock -ScriptBlock {
            param(
                [pscustomobject]$Connection,

                [int]$BuildId
            )

            $requestContext = Get-GerberPluginApiAdoRequestContext -Connection $Connection
            return Get-GerberAdoBuildRunUrl -Configuration $requestContext.Configuration -BuildId $BuildId
        }
    }
