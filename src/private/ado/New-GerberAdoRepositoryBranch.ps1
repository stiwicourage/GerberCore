function New-GerberAdoRepositoryBranch {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [string]$RepoId,

        [Parameter(Mandatory)]
        [string]$BranchRef,

        [Parameter(Mandatory)]
        [string]$DefaultBranchRef
    )
    $null = $PSCmdlet.ShouldProcess('New-GerberAdoRepositoryBranch', 'Invoke')

    try {
        $projectScope = Resolve-GerberAdoProjectScope -Context $Context
        $relPath = "$projectScope/_apis/git/repositories/$RepoId/refs"
        $uri = Get-GerberAdoBranchRequestUri -Configuration $Context.Configuration -RelativePath $relPath
        $defaultCommit = Get-GerberAdoRepositoryBranchCommit -Context $Context -RepoId $RepoId -BranchRef $DefaultBranchRef
        $body = ConvertTo-Json -InputObject @(@{
            name = $BranchRef
            oldObjectId = '0000000000000000000000000000000000000000'
            newObjectId = $defaultCommit
        }) -Compress
        $mutationContext = [pscustomobject]@{
            Uri = $uri; Pat = $Context.Pat; Method = 'Post'; Body = $body
            RequestLabel = "branch $BranchRef for repository $RepoId"
            CredentialIdentifier = $Context.Configuration.CredentialIdentifier
        }
        $null = Invoke-GerberAdoRestMutation -MutationContext $mutationContext
        return [pscustomobject]@{ Success = $true }
    } catch {
        return [pscustomobject]@{ Success = $false }
    }
}

function Get-GerberAdoRepositoryBranchCommit {
    [OutputType([string])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [string]$RepoId,

        [Parameter(Mandatory)]
        [string]$BranchRef
    )
    $null = $PSCmdlet.ShouldProcess('Get-GerberAdoRepositoryBranchCommit', 'Invoke')

    $filter = $BranchRef -replace '^refs/', ''
    $projectScope = Resolve-GerberAdoProjectScope -Context $Context
    $relPath = "$projectScope/_apis/git/repositories/$RepoId/refs"
    $uri = Get-GerberAdoBranchRequestUri -Configuration $Context.Configuration -RelativePath $relPath -Filter $filter
    $response = Invoke-GerberAdoRestRequest `
        -Uri $uri `
        -Pat $Context.Pat `
        -RequestLabel "commit for $BranchRef in repository $RepoId" `
        -CredentialIdentifier $Context.Configuration.CredentialIdentifier
    $refs = @(Get-GerberAdoResponseValueList -Response $response)
    return [string]$refs[0].objectId
}
