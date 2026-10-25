function Get-GerberAdoPullRequestChangedFileList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [pscustomobject]$PullRequest
    )

    $iterationId = Get-GerberAdoPullRequestLatestIterationId -Context $Context -PullRequest $PullRequest
    $uri = Get-GerberAdoPullRequestChangeUri -Context $Context -PullRequest $PullRequest -IterationId $iterationId
    $response = Invoke-GerberAdoRestRequest `
        -Uri $uri `
        -Pat $Context.Pat `
        -RequestLabel "changed files for pull request $($PullRequest.PullRequestId)" `
        -CredentialIdentifier $Context.Configuration.CredentialIdentifier

    return @(
        foreach ($changeEntry in @(Get-GerberAdoPullRequestChangeEntryList -Response $response)) {
            $item = $changeEntry.item
            $path = Resolve-GerberAdoPullRequestPathValue -ChangeEntry $changeEntry -PropertyName 'path'
            if ([string]::IsNullOrWhiteSpace($path) -and ($null -ne $item)) {
                $path = [string]$item.path
            }

            if ([string]::IsNullOrWhiteSpace($path)) {
                continue
            }

            [pscustomobject]@{
                Path = $path
                OriginalPath = Resolve-GerberAdoPullRequestPathValue -ChangeEntry $changeEntry -PropertyName 'originalPath'
                ChangeType = Get-GerberAdoPullRequestChangeType -ChangeEntry $changeEntry
            }
        }
    )
}

function Get-GerberAdoPullRequestLatestIterationId {
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [pscustomobject]$PullRequest
    )

    $relativePath = "$($PullRequest.ProjectName)/_apis/git/repositories/$($PullRequest.RepositoryId)/pullRequests/$($PullRequest.PullRequestId)/iterations"
    $uri = Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($Context.Configuration.CollectionUri, $relativePath)) `
        -QueryParameterMap ([ordered]@{
            'api-version' = $Context.Configuration.DefaultApiVersion
        })
    $response = Invoke-GerberAdoRestRequest `
        -Uri $uri `
        -Pat $Context.Pat `
        -RequestLabel "iterations for pull request $($PullRequest.PullRequestId)" `
        -CredentialIdentifier $Context.Configuration.CredentialIdentifier

    $iterationList = @(
        foreach ($item in @(Get-GerberAdoResponseValueList -Response $response)) {
            [int]$item.id
        }
    )
    if ($iterationList.Count -eq 0) {
        throw [System.ArgumentException]::new("Gerber could not find any iterations for pull request $($PullRequest.PullRequestId).")
    }

    return ($iterationList | Measure-Object -Maximum).Maximum
}

function Get-GerberAdoPullRequestChangeUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [pscustomobject]$PullRequest,

        [Parameter(Mandatory)]
        [int]$IterationId
    )

    $relativePath = "$($PullRequest.ProjectName)/_apis/git/repositories/$($PullRequest.RepositoryId)/pullRequests/$($PullRequest.PullRequestId)/iterations/$IterationId/changes"
    return Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($Context.Configuration.CollectionUri, $relativePath)) `
        -QueryParameterMap ([ordered]@{
            'api-version' = $Context.Configuration.DefaultApiVersion
            '$top' = '2000'
        })
}

function Get-GerberAdoPullRequestChangeEntryList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Response
    )

    if ($null -eq $Response) {
        return @()
    }

    foreach ($propertyName in @('changeEntries', 'changes', 'value')) {
        if (($Response -is [hashtable]) -and $Response.ContainsKey($propertyName)) {
            return @($Response[$propertyName])
        }

        if ($Response.PSObject.Properties.Match($propertyName).Count -gt 0) {
            return @($Response.$propertyName)
        }
    }

    return @()
}

function Resolve-GerberAdoPullRequestPathValue {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$ChangeEntry,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    if ($ChangeEntry.PSObject.Properties.Match($PropertyName).Count -gt 0) {
        return [string]$ChangeEntry.$PropertyName
    }

    return ''
}

function Get-GerberAdoPullRequestChangeType {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$ChangeEntry
    )

    if ($ChangeEntry.PSObject.Properties.Match('changeType').Count -gt 0) {
        return [string]$ChangeEntry.changeType
    }

    if ($ChangeEntry.PSObject.Properties.Match('changeTrackingId').Count -gt 0) {
        return [string]$ChangeEntry.changeTrackingId
    }

    return ''
}
