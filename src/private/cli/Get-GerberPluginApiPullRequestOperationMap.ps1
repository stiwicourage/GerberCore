function Get-GerberPluginApiPullRequestOperationMap {
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    [CmdletBinding()]
    param()

    return [ordered]@{
        ResolvePullRequestReference = Get-GerberModuleBoundScriptBlock -ScriptBlock {
            param(
                [Parameter(Mandatory)]
                [pscustomobject]$Connection,

                [Parameter(Mandatory)]
                [string]$InputText
            )

            $requestContext = Get-GerberPluginApiAdoRequestContext -Connection $Connection
            return Resolve-GerberAdoPullRequestReference -InputText $InputText -Configuration $requestContext.Configuration
        }
        GetPullRequest = Get-GerberModuleBoundScriptBlock -ScriptBlock {
            param(
                [Parameter(Mandatory)]
                [pscustomobject]$Connection,

                [Parameter(Mandatory)]
                [pscustomobject]$PullRequestReference
            )

            $requestContext = Get-GerberPluginApiAdoRequestContext -Connection $Connection -RequireAuthentication
            return Get-GerberAdoPullRequest `
                -Configuration $requestContext.Configuration `
                -Pat $requestContext.Pat `
                -PullRequestReference $PullRequestReference
        }
        GetPullRequestChangedFileList = Get-GerberModuleBoundScriptBlock -ScriptBlock {
            param(
                [Parameter(Mandatory)]
                [pscustomobject]$Connection,

                [Parameter(Mandatory)]
                [pscustomobject]$PullRequest
            )

            $requestContext = Get-GerberPluginApiAdoRequestContext -Connection $Connection -RequireAuthentication
            return @(Get-GerberAdoPullRequestChangedFileList -Context $requestContext -PullRequest $PullRequest)
        }
        GetPullRequestFileContent = Get-GerberModuleBoundScriptBlock -ScriptBlock {
            param(
                [Parameter(Mandatory)]
                [pscustomobject]$Connection,

                [Parameter(Mandatory)]
                [pscustomobject]$PullRequest,

                [Parameter(Mandatory)]
                [string]$Path,

                [bool]$AllowMissing = $false
            )

            $requestContext = Get-GerberPluginApiAdoRequestContext -Connection $Connection -RequireAuthentication
            return Get-GerberAdoPullRequestFileContent `
                -Context $requestContext `
                -PullRequest $PullRequest `
                -Path $Path `
                -AllowMissing:$AllowMissing
        }
        GetPullRequestBuildValidationStatus = Get-GerberModuleBoundScriptBlock -ScriptBlock {
            param(
                [Parameter(Mandatory)]
                [pscustomobject]$Connection,

                [Parameter(Mandatory)]
                [pscustomobject]$PullRequest
            )

            $requestContext = Get-GerberPluginApiAdoRequestContext -Connection $Connection -RequireAuthentication
            return Get-GerberAdoPullRequestBuildValidationStatus `
                -Context $requestContext `
                -PullRequest $PullRequest
        }
    }
}
