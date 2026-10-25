function Get-GerberAdoPipelineDefinition {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [int]$PipelineId
    )

    try {
        $projectScope = Resolve-GerberAdoProjectScope -Context $Context
        $relPath = "$projectScope/_apis/pipelines/$PipelineId"
        $uri = Get-GerberAdoBranchRequestUri -Configuration $Context.Configuration -RelativePath $relPath
        $response = Invoke-GerberAdoRestRequest `
            -Uri $uri `
            -Pat $Context.Pat `
            -RequestLabel "pipeline definition $PipelineId" `
            -CredentialIdentifier $Context.Configuration.CredentialIdentifier
        return [pscustomobject]@{ Success = $true; YamlPath = [string]$response.configuration.path }
    } catch {
        return [pscustomobject]@{ Success = $false; YamlPath = '' }
    }
}
