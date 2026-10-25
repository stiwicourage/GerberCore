function Get-GerberAdoPullRequestBuildValidationStatus {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [pscustomobject]$PullRequest
    )

    $uri = Get-GerberAdoBuildValidationStatusUri -Context $Context -PullRequest $PullRequest

    try {
        $response = Invoke-GerberAdoRestRequest `
            -Uri $uri `
            -Pat $Context.Pat `
            -RequestLabel "statuses for pull request $($PullRequest.PullRequestId)" `
            -CredentialIdentifier $Context.Configuration.CredentialIdentifier
    } catch [System.ArgumentException] {
        return [pscustomobject]@{
            IsAvailable = $false
            StatusList = @()
            ErrorMessage = $_.Exception.Message
        }
    }

    $statusList = @(ConvertTo-GerberAdoBuildValidationStatusEntryList -Response $response)
    if ($statusList.Count -eq 0) {
        $statusList = @(Get-GerberAdoBuildValidationFallbackStatusList -Context $Context -PullRequest $PullRequest)
    }

    return [pscustomobject]@{
        IsAvailable = $true
        StatusList = $statusList
        ErrorMessage = ''
    }
}

function Get-GerberAdoBuildValidationStatusUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [pscustomobject]$PullRequest
    )

    $relativePath = "$($PullRequest.ProjectName)/_apis/git/repositories/$($PullRequest.RepositoryId)/pullRequests/$($PullRequest.PullRequestId)/statuses"
    return Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($Context.Configuration.CollectionUri, $relativePath)) `
        -QueryParameterMap ([ordered]@{
            'api-version' = $Context.Configuration.DefaultApiVersion
        })
}

function ConvertTo-GerberAdoBuildValidationStatusEntryList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Response
    )

    return @(
        foreach ($status in @(Get-GerberAdoResponseValueList -Response $Response)) {
            [pscustomobject]@{
                State = [string]$status.state
                Description = [string]$status.description
                ContextName = [string]$status.context.name
            }
        }
    )
}

function Get-GerberAdoBuildValidationFallbackStatusList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [pscustomobject]$PullRequest
    )

    $policyEvaluationList = @()
    try {
        $policyEvaluationList = @(Get-GerberAdoPullRequestPolicyEvaluationList -Context $Context -PullRequest $PullRequest)
    } catch [System.ArgumentException] {
        $policyEvaluationList = @()
    }

    return @(
        @(Get-GerberAdoPolicyStatusEntryOrNull -PolicyEvaluationList $policyEvaluationList)
        @(Get-GerberAdoMergeStatusEntryOrNull -MergeStatus $PullRequest.MergeStatus)
    )
}

function Get-GerberAdoPolicyStatusEntryOrNull {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$PolicyEvaluationList
    )

    $relevantPolicyEvaluationList = @(Get-GerberAdoRelevantPolicyEvaluationList -PolicyEvaluationList $PolicyEvaluationList)
    if ($relevantPolicyEvaluationList.Count -eq 0) {
        return $null
    }

    $failedPolicyEvaluationList = @($relevantPolicyEvaluationList | Where-Object { $_.Status -in @('broken', 'rejected') })
    if ($failedPolicyEvaluationList.Count -gt 0) {
        return ConvertTo-GerberAdoSyntheticStatus `
            -ContextName 'Azure DevOps checks' `
            -State 'failed' `
            -Description "Required checks failed: $(Format-GerberAdoPolicyEvaluationList -PolicyEvaluationList $failedPolicyEvaluationList)."
    }

    $pendingPolicyEvaluationList = @($relevantPolicyEvaluationList | Where-Object { $_.Status -ne 'approved' })
    if ($pendingPolicyEvaluationList.Count -eq 0) {
        return ConvertTo-GerberAdoSyntheticStatus `
            -ContextName 'Azure DevOps checks' `
            -State 'succeeded' `
            -Description 'All required checks succeeded.'
    }

    return ConvertTo-GerberAdoSyntheticStatus `
        -ContextName 'Azure DevOps checks' `
        -State 'pending' `
        -Description "Required checks are still pending: $(Format-GerberAdoPolicyEvaluationList -PolicyEvaluationList $pendingPolicyEvaluationList)."
}

function Get-GerberAdoRelevantPolicyEvaluationList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$PolicyEvaluationList
    )

    return @(
        foreach ($policyEvaluation in @($PolicyEvaluationList)) {
            if ((-not $policyEvaluation.IsBlocking) -or (-not $policyEvaluation.IsEnabled)) {
                continue
            }

            if ($policyEvaluation.Status -eq 'notApplicable') {
                continue
            }

            if (Test-GerberAdoReviewerPolicyType -TypeId $policyEvaluation.TypeId) {
                continue
            }

            $policyEvaluation
        }
    )
}

function Test-GerberAdoReviewerPolicyType {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TypeId
    )

    return $TypeId -in @(
        'fd2167ab-b0be-447a-8ec8-39368250530e',
        'fa4e907d-c16b-452d-8106-7efa0cb84489'
    )
}

function Format-GerberAdoPolicyEvaluationList {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$PolicyEvaluationList
    )

    $labelList = foreach ($policyEvaluation in @($PolicyEvaluationList)) {
        $displayName = if ([string]::IsNullOrWhiteSpace($policyEvaluation.DisplayName)) { 'Policy' } else { $policyEvaluation.DisplayName }
        "$displayName ($($policyEvaluation.Status))"
    }

    return [string]::Join(', ', @($labelList | Select-Object -Unique))
}

function Get-GerberAdoMergeStatusEntryOrNull {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$MergeStatus
    )

    if ([string]::IsNullOrWhiteSpace($MergeStatus)) {
        return $null
    }

    switch ($MergeStatus.ToLowerInvariant()) {
        'succeeded' {
            return ConvertTo-GerberAdoSyntheticStatus -ContextName 'Azure DevOps merge' -State 'succeeded' -Description 'No merge conflicts.'
        }
        'conflicts' {
            return ConvertTo-GerberAdoSyntheticStatus -ContextName 'Azure DevOps merge' -State 'failed' -Description 'Merge conflicts detected.'
        }
        'failure' {
            return ConvertTo-GerberAdoSyntheticStatus -ContextName 'Azure DevOps merge' -State 'failed' -Description 'Azure DevOps could not calculate merge status.'
        }
        'rejectedbypolicy' {
            return ConvertTo-GerberAdoSyntheticStatus -ContextName 'Azure DevOps merge' -State 'failed' -Description 'Merge is currently blocked by policy.'
        }
        'queued' {
            return ConvertTo-GerberAdoSyntheticStatus -ContextName 'Azure DevOps merge' -State 'pending' -Description 'Merge validation is still running.'
        }
        'notset' {
            return ConvertTo-GerberAdoSyntheticStatus -ContextName 'Azure DevOps merge' -State 'pending' -Description 'Merge validation has not started yet.'
        }
    }

    return $null
}

function ConvertTo-GerberAdoSyntheticStatus {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ContextName,

        [Parameter(Mandatory)]
        [string]$State,

        [Parameter(Mandatory)]
        [string]$Description
    )

    return [pscustomobject]@{
        State = $State
        Description = $Description
        ContextName = $ContextName
    }
}
