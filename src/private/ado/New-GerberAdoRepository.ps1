function New-GerberAdoRepository {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context
    )
    $null = $PSCmdlet.ShouldProcess('New-GerberAdoRepository', 'Invoke')

    $uri = $null
    try {
        $projectScope = Resolve-GerberAdoProjectScope -Context $Context
        $relPath = "$projectScope/_apis/git/repositories"
        $uri = Get-GerberAdoBranchRequestUri -Configuration $Context.Configuration -RelativePath $relPath
        $body = ConvertTo-Json -InputObject @{
            name = $Context.RepositoryName
            project = @{ id = $Context.Project.Id }
        } -Compress
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
        return [pscustomobject]@{ Success = $true; RepoId = [string]$result.id }
    } catch {
        $errorDetail = if ($null -ne $uri) {
            $message = Get-GerberAdoRequestFailureMessage `
                -Uri $uri `
                -RequestLabel "repository '$($Context.RepositoryName)'" `
                -CredentialIdentifier $Context.Configuration.CredentialIdentifier `
                -Exception $_.Exception
            Write-Error -Message $message -ErrorAction SilentlyContinue
            $_.Exception.Message
        } else {
            $_.Exception.Message
        }
        return [pscustomobject]@{ Success = $false; RepoId = ''; ErrorDetail = $errorDetail }
    }
}
