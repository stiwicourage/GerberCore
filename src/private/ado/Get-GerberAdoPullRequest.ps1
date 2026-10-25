function Get-GerberAdoPullRequest {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [pscustomobject]$PullRequestReference
    )

    $uri = Get-GerberAdoPullRequestUri -Configuration $Configuration -PullRequestReference $PullRequestReference
    $response = Invoke-GerberAdoRestRequest `
        -Uri $uri `
        -Pat $Pat `
        -RequestLabel "pull request $($PullRequestReference.PullRequestId)" `
        -CredentialIdentifier $Configuration.CredentialIdentifier

    $repository = $response.repository
    if ($null -eq $repository) {
        throw [System.ArgumentException]::new("Gerber could not load repository details for pull request $($PullRequestReference.PullRequestId).")
    }

    $projectId = [string]$repository.project.id
    if ([string]::IsNullOrWhiteSpace($projectId)) {
        throw [System.ArgumentException]::new("Gerber could not load project details for pull request $($PullRequestReference.PullRequestId).")
    }

    if ((-not [string]::IsNullOrWhiteSpace($PullRequestReference.RepositoryName)) -and
        ($repository.name -ne $PullRequestReference.RepositoryName)) {
        throw [System.ArgumentException]::new(
            "Gerber resolved pull request $($PullRequestReference.PullRequestId) to repository '$($repository.name)', which did not match '$($PullRequestReference.RepositoryName)' from the URL."
        )
    }

    return [pscustomobject]@{
        ProjectName = $PullRequestReference.ProjectName
        ProjectId = $projectId
        PullRequestId = [int]$response.pullRequestId
        Title = [string]$response.title
        RepositoryId = [string]$repository.id
        RepositoryName = [string]$repository.name
        SourceRefName = [string]$response.sourceRefName
        TargetRefName = [string]$response.targetRefName
        SourceCommitId = [string]$response.lastMergeSourceCommit.commitId
        MergeStatus = [string]$response.mergeStatus
        Status = [string]$response.status
        Url = [string]$response.url
    }
}

function Get-GerberAdoPullRequestUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [pscustomobject]$PullRequestReference
    )

    $relativePath = "$($PullRequestReference.ProjectName)/_apis/git/pullrequests/$($PullRequestReference.PullRequestId)"
    return Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($Configuration.CollectionUri, $relativePath)) `
        -QueryParameterMap ([ordered]@{
            'api-version' = $Configuration.DefaultApiVersion
        })
}
