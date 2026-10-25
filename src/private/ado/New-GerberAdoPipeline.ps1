function New-GerberAdoPipeline {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [string]$RepoId,

        [Parameter(Mandatory)]
        [string]$YamlPath,

        [Parameter(Mandatory)]
        [string]$DefaultBranchRef
    )
    $null = $PSCmdlet.ShouldProcess('New-GerberAdoPipeline', 'Invoke')

    $uri = $null
    try {
        $projectScope = Resolve-GerberAdoProjectScope -Context $Context
        $relPath = "$projectScope/_apis/pipelines"
        $uri = Get-GerberAdoBranchRequestUri -Configuration $Context.Configuration -RelativePath $relPath
        $pipelineStem = [System.IO.Path]::GetFileNameWithoutExtension($YamlPath)
        $pipelineName = $pipelineStem -replace '-', ' '
        $normalizedPath = if ($YamlPath.StartsWith('/')) { $YamlPath } else { "/$YamlPath" }
        $fullPipelineName = "$($Context.RepositoryName) ($pipelineName)"
        $body = ConvertTo-Json -InputObject @{
            name = $fullPipelineName
            folder = '\'
            configuration = @{
                type = 'yaml'
                path = $normalizedPath
                repository = @{
                    id            = $RepoId
                    name          = $Context.RepositoryName
                    type          = 'azureReposGit'
                    defaultBranch = $DefaultBranchRef
                }
            }
        } -Depth 5 -Compress
        $httpConfig = Get-GerberHttpConfiguration
        $headers = Get-GerberAdoRequestHeader -Pat $Context.Pat
        $result = Invoke-RestMethod `
            -Method Post `
            -Uri $uri `
            -Headers $headers `
            -Body $body `
            -ContentType 'application/json' `
            -ConnectionTimeoutSeconds $httpConfig.ConnectionTimeoutSeconds `
            -OperationTimeoutSeconds $httpConfig.OperationTimeoutSeconds `
            -ErrorAction Stop
        return [pscustomobject]@{ Success = $true; PipelineId = [int]$result.id; YamlPath = $normalizedPath; PipelineName = $fullPipelineName }
    } catch {
        $message = if ($null -ne $uri) {
            Get-GerberAdoRequestFailureMessage `
                -Uri $uri `
                -RequestLabel "pipeline for $YamlPath in repository $RepoId" `
                -CredentialIdentifier $Context.Configuration.CredentialIdentifier `
                -Exception $_.Exception
        } else {
            $_.Exception.Message
        }
        return [pscustomobject]@{ Success = $false; ErrorDetail = $message }
    }
}
