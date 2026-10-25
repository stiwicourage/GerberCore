function Get-GerberAdoPullRequestPolicyEvaluationList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [pscustomobject]$PullRequest
    )

    if ([string]::IsNullOrWhiteSpace([string]$PullRequest.ProjectId)) {
        return @()
    }

    $uri = Get-GerberAdoPullRequestPolicyEvaluationUri -Context $Context -PullRequest $PullRequest
    $response = Invoke-GerberAdoRestRequest `
        -Uri $uri `
        -Pat $Context.Pat `
        -RequestLabel "policy evaluations for pull request $($PullRequest.PullRequestId)" `
        -CredentialIdentifier $Context.Configuration.CredentialIdentifier

    return @(
        foreach ($evaluation in @(Get-GerberAdoResponseValueList -Response $response)) {
            ConvertTo-GerberAdoPolicyEvaluation -Evaluation $evaluation
        }
    )
}

function Get-GerberAdoPullRequestPolicyEvaluationUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [pscustomobject]$PullRequest
    )

    $relativePath = "$($PullRequest.ProjectName)/_apis/policy/evaluations"
    $artifactId = Get-GerberAdoPullRequestPolicyArtifactId -ProjectId $PullRequest.ProjectId -PullRequestId $PullRequest.PullRequestId
    return Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($Context.Configuration.CollectionUri, $relativePath)) `
        -QueryParameterMap ([ordered]@{
            artifactId = $artifactId
            'api-version' = $Context.Configuration.PolicyEvaluationApiVersion
        })
}

function Get-GerberAdoPullRequestPolicyArtifactId {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProjectId,

        [Parameter(Mandatory)]
        [int]$PullRequestId
    )

    return "vstfs:///CodeReview/CodeReviewId/$ProjectId/$PullRequestId"
}

function ConvertTo-GerberAdoPolicyEvaluation {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Evaluation
    )

    $configuration = $Evaluation.configuration
    $policyType = $configuration.type
    return [pscustomobject]@{
        DisplayName = [string]$policyType.displayName
        TypeId = [string]$policyType.id
        Status = [string]$Evaluation.status
        IsBlocking = [bool]$configuration.isBlocking
        IsEnabled = [bool]$configuration.isEnabled
    }
}
