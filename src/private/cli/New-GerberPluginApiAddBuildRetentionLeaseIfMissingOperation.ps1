function New-GerberPluginApiAddBuildRetentionLeaseIfMissingOperation {
        [OutputType([scriptblock])]
        [CmdletBinding(SupportsShouldProcess)]
        param()
        $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiAddBuildRetentionLeaseIfMissingOperation', 'Invoke')

        return Get-GerberModuleBoundScriptBlock -ScriptBlock {
            param(
                [pscustomobject]$Connection,
                [int]$DefinitionId,
                [int]$BuildId
            )

            $requestContext = Get-GerberPluginApiAdoRequestContext -Connection $Connection -RequireAuthentication
            return Add-GerberAdoBuildRetentionLeaseIfMissing `
                -Configuration $requestContext.Configuration `
                -Pat $requestContext.Pat `
                -DefinitionId $DefinitionId `
                -BuildId $BuildId
        }
    }
