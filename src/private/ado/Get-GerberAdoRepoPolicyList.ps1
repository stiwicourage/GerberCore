function Get-GerberAdoRepoPolicyList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [string]$RepoId
    )

    $projectScope = Resolve-GerberAdoProjectScope -Context $Context
    $relPath = "$projectScope/_apis/policy/configurations"
    $uri = Get-GerberAdoBranchRequestUri -Configuration $Context.Configuration -RelativePath $relPath
    $response = Invoke-GerberAdoRestRequest `
        -Uri $uri `
        -Pat $Context.Pat `
        -RequestLabel "policies for repository $RepoId" `
        -CredentialIdentifier $Context.Configuration.CredentialIdentifier
    return @(
        Get-GerberAdoResponseValueList -Response $response |
            Where-Object { Test-GerberAdoPolicyForRepo -Policy $_ -RepoId $RepoId } |
            ForEach-Object { [pscustomobject]@{ Id = [int]$_.id; Type = $_.type; Settings = $_.settings } }
    )
}

function Test-GerberAdoPolicyForRepo {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Policy,

        [Parameter(Mandatory)]
        [string]$RepoId
    )

    $scopes = @($Policy.settings.scope)
    return @($scopes | Where-Object { $_.repositoryId -eq $RepoId }).Count -gt 0
}
