function Set-GerberAdoSearchableBranchPolicy {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [pscustomobject]$PolicyItem
    )

    try {
        if ($null -eq $PolicyItem.PolicyId) {
            if ($PSCmdlet.ShouldProcess($PolicyItem.RepoName, 'Create searchable-branch policy')) {
                Invoke-GerberAdoCreateSearchableBranchPolicy -Context $Context -PolicyItem $PolicyItem
            }
            return [pscustomobject]@{ RepoName = $PolicyItem.RepoName; Success = $true; IsCreate = $true }
        }
        if ($PSCmdlet.ShouldProcess($PolicyItem.RepoName, 'Update searchable-branch policy')) {
            Invoke-GerberAdoUpdateSearchableBranchPolicy -Context $Context -PolicyItem $PolicyItem
        }
        return [pscustomobject]@{ RepoName = $PolicyItem.RepoName; Success = $true; IsCreate = $false }
    } catch {
        return [pscustomobject]@{ RepoName = $PolicyItem.RepoName; Success = $false; IsCreate = ($null -eq $PolicyItem.PolicyId) }
    }
}

function Invoke-GerberAdoCreateSearchableBranchPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [pscustomobject]$PolicyItem
    )

    $uri = Get-GerberAdoSearchableBranchPolicyWriteUri -Configuration $Context.Configuration
    $body = Build-GerberAdoSearchableBranchPolicyBody -PolicyItem $PolicyItem
    $mutationContext = [pscustomobject]@{
        Uri = $uri; Pat = $Context.Pat; Method = 'Post'; Body = $body
        RequestLabel = "searchable branch policy for '$($PolicyItem.RepoName)'"
        CredentialIdentifier = $Context.Configuration.CredentialIdentifier
    }
    Invoke-GerberAdoRestMutation -MutationContext $mutationContext
}

function Invoke-GerberAdoUpdateSearchableBranchPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [pscustomobject]$PolicyItem
    )

    $uri = Get-GerberAdoSearchableBranchPolicyWriteUri -Configuration $Context.Configuration -PolicyId $PolicyItem.PolicyId
    $body = Build-GerberAdoSearchableBranchPolicyBody -PolicyItem $PolicyItem -PolicyId $PolicyItem.PolicyId
    $mutationContext = [pscustomobject]@{
        Uri = $uri; Pat = $Context.Pat; Method = 'Put'; Body = $body
        RequestLabel = "searchable branch policy for '$($PolicyItem.RepoName)'"
        CredentialIdentifier = $Context.Configuration.CredentialIdentifier
    }
    Invoke-GerberAdoRestMutation -MutationContext $mutationContext
}

function Build-GerberAdoSearchableBranchPolicyBody {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PolicyItem,

        [AllowNull()]
        [string]$PolicyId = $null
    )

    $policyTypeId = Get-GerberSearchableBranchPolicyTypeId
    $body = [ordered]@{
        isEnabled  = $true
        isBlocking = $false
        type       = [ordered]@{ id = $policyTypeId }
        settings   = [ordered]@{
            scope          = @([ordered]@{ repositoryId = $PolicyItem.RepoId })
            searchBranches = @($PolicyItem.NewScope)
        }
    }
    if (-not [string]::IsNullOrEmpty($PolicyId)) {
        $body['id'] = [int]$PolicyId
    }
    return ConvertTo-Json -InputObject $body -Depth 10 -Compress
}

function Get-GerberAdoSearchableBranchPolicyWriteUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [AllowNull()]
        [string]$PolicyId = $null
    )

    $relPath = "$($Configuration.ProjectName)/_apis/policy/configurations"
    $fullRelPath = if ([string]::IsNullOrEmpty($PolicyId)) { $relPath } else { "$relPath/$PolicyId" }
    $queryMap = [ordered]@{ 'api-version' = $Configuration.DefaultApiVersion }
    return Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($Configuration.CollectionUri, $fullRelPath)) `
        -QueryParameterMap $queryMap
}
