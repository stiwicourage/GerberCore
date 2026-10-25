function Set-GerberAdoRepositoryDefaultBranch {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [pscustomobject]$RepoItem
    )

    try {
        if ($PSCmdlet.ShouldProcess($RepoItem.RepoName, 'Set default branch')) {
            $uri = Get-GerberAdoRepositoryPatchUri -Configuration $Context.Configuration -RepoId $RepoItem.RepoId
            $body = Build-GerberAdoRepositoryDefaultBranchBody -TargetBranch $Context.TargetBranch
            $mutationContext = [pscustomobject]@{
                Uri                     = $uri
                Pat                     = $Context.Pat
                Method                  = 'Patch'
                Body                    = $body
                RequestLabel            = "default branch for '$($RepoItem.RepoName)'"
                CredentialIdentifier = $Context.Configuration.CredentialIdentifier
            }
            Invoke-GerberAdoRestMutation -MutationContext $mutationContext
        }
        return [pscustomobject]@{ RepoName = $RepoItem.RepoName; Success = $true }
    } catch {
        return [pscustomobject]@{ RepoName = $RepoItem.RepoName; Success = $false }
    }
}

function Get-GerberAdoRepositoryPatchUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$RepoId,

        [string]$ProjectScope
    )

    $resolvedProjectScope = if ($PSBoundParameters.ContainsKey('ProjectScope')) { $ProjectScope } else { $Configuration.ProjectName }
    $relPath = "$resolvedProjectScope/_apis/git/repositories/$RepoId"
    return Get-GerberAdoBranchRequestUri -Configuration $Configuration -RelativePath $relPath
}

function Build-GerberAdoRepositoryDefaultBranchBody {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TargetBranch
    )

    return ConvertTo-Json -InputObject @{ defaultBranch = $TargetBranch } -Compress
}
