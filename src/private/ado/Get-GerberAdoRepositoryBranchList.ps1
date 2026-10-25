function Get-GerberAdoRepositoryBranchList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [string]$RepoId
    )

    $projectScope = Resolve-GerberAdoProjectScope -Context $Context
    $relPath = "$projectScope/_apis/git/repositories/$RepoId/refs"
    $uri = Get-GerberAdoBranchRequestUri -Configuration $Context.Configuration -RelativePath $relPath -Filter 'heads/'
    $response = Invoke-GerberAdoRestRequest `
        -Uri $uri `
        -Pat $Context.Pat `
        -RequestLabel "branches for repository $RepoId" `
        -CredentialIdentifier $Context.Configuration.CredentialIdentifier
    return [string[]]@(
        Get-GerberAdoResponseValueList -Response $response |
            ForEach-Object { [string]$_.name }
    )
}
