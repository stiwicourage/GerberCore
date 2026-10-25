function Get-GerberSearchableBranchPolicyTypeId {
    [OutputType([string])]
    [CmdletBinding()]
    param()
    return '0517f88d-4ec5-4343-9d26-9930ebd53069'
}

function Get-GerberAdoSearchableBranchPolicyReport {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context
    )

    $repoList = @(Get-GerberAdoRepositoryList -Configuration $Context.Configuration -Pat $Context.Pat)
    $policyMap = Get-GerberAdoSearchableBranchPolicyMap -Context $Context
    Write-GerberPromptTrace -EventName 'set-searchable-policy-map' -Data @{
        PolicyCount = $policyMap.Count
    }
    $scanResult = Invoke-GerberSearchableBranchRepoScan -Context $Context -RepoList $repoList -PolicyMap $policyMap
    return [pscustomobject]@{
        RepoList           = $repoList
        CreateList         = @($scanResult.CreateList)
        UpdateList         = @($scanResult.UpdateList)
        AlreadyAlignedList = @($scanResult.AlignedList)
    }
}

function Invoke-GerberSearchableBranchRepoScan {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$RepoList,

        [Parameter(Mandatory)]
        [hashtable]$PolicyMap
    )

    $lists = [pscustomobject]@{
        CreateList = [System.Collections.Generic.List[pscustomobject]]::new()
        UpdateList = [System.Collections.Generic.List[pscustomobject]]::new()
        AlignedList = [System.Collections.Generic.List[pscustomobject]]::new()
    }
    $total = $RepoList.Count
    $index = 0
    foreach ($repo in $RepoList) {
        $index++
        Write-GerberProgressBar -Current $index -Total $total -Prefix 'Scanning repositories...'
        $item = Get-GerberSearchableBranchPlanItem -Context $Context -Repo $repo -PolicyMap $PolicyMap
        Add-GerberSearchableBranchPlanItem -Item $item -Lists $lists
    }
    return $lists
}

function Add-GerberSearchableBranchPlanItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Item,

        [Parameter(Mandatory)]
        [pscustomobject]$Lists
    )

    if (-not $Item.NeedsChange) {
        $null = $Lists.AlignedList.Add([pscustomobject]@{ RepoName = $Item.RepoName })
        return
    }
    if ($null -eq $Item.PolicyId) {
        $null = $Lists.CreateList.Add($Item)
        return
    }
    $null = $Lists.UpdateList.Add($Item)
}

function Get-GerberSearchableBranchPlanItem {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [pscustomobject]$Repo,

        [Parameter(Mandatory)]
        [hashtable]$PolicyMap
    )

    $policy = $PolicyMap[$Repo.Id]
    $currentBranches = @(Get-GerberSearchableBranchCurrentBranchList -Policy $policy)
    $policyId = if ($null -ne $policy) { [string]$policy.id } else { $null }
    $newScope = @(Build-GerberSearchableBranchNewScope `
        -DesiredBranchList $Context.DesiredBranchList -CurrentBranches $currentBranches `
        -Mode $Context.Mode -DefaultBranch $Repo.DefaultBranch)
    $needsChange = -not (Test-GerberSearchableBranchScopeAligned -NewScope $newScope -CurrentScope $currentBranches)
    Write-GerberPromptTrace -EventName 'set-searchable-plan-item' -Data @{
        RepoName = $Repo.Name; PolicyId = $policyId; NeedsChange = $needsChange
        CurrentBranchesCount = $currentBranches.Count; NewScopeCount = $newScope.Count
    }
    return [pscustomobject]@{ RepoId = $Repo.Id; RepoName = $Repo.Name; PolicyId = $policyId; NewScope = $newScope; NeedsChange = $needsChange }
}

function Get-GerberSearchableBranchCurrentBranchList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Policy
    )

    if ($null -eq $Policy) { return [string[]]@() }
    if ($null -eq $Policy.settings -or $null -eq $Policy.settings.searchBranches) { return [string[]]@() }
    return [string[]]@($Policy.settings.searchBranches | Where-Object { -not [string]::IsNullOrEmpty($_) })
}

function Get-GerberAdoSearchableBranchAllPoliciesUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration
    )

    $policyTypeId = Get-GerberSearchableBranchPolicyTypeId
    $relPath = "$($Configuration.ProjectName)/_apis/policy/configurations"
    $queryMap = [ordered]@{
        policyType    = $policyTypeId
        'api-version' = $Configuration.DefaultApiVersion
    }
    return Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($Configuration.CollectionUri, $relPath)) `
        -QueryParameterMap $queryMap
}

function Add-GerberAdoSearchableBranchPolicyToMap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Policy,

        [Parameter(Mandatory)]
        [hashtable]$Map
    )

    foreach ($scopeEntry in @($Policy.settings.scope)) {
        if (-not [string]::IsNullOrEmpty($scopeEntry.repositoryId)) {
            $Map[$scopeEntry.repositoryId] = $Policy
        }
    }
}

function Get-GerberAdoSearchableBranchPolicyMap {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context
    )

    $policyTypeId = Get-GerberSearchableBranchPolicyTypeId
    $uri = Get-GerberAdoSearchableBranchAllPoliciesUri -Configuration $Context.Configuration
    $response = Invoke-GerberAdoRestRequest -Uri $uri -Pat $Context.Pat `
        -RequestLabel 'searchable branch policies' -CredentialIdentifier $Context.Configuration.CredentialIdentifier
    $valueList = @(Get-GerberAdoResponseValueList -Response $response)
    $map = @{}
    foreach ($policy in $valueList) {
        if ($policy.type.id -ne $policyTypeId) { continue }
        Add-GerberAdoSearchableBranchPolicyToMap -Policy $policy -Map $map
    }
    return $map
}

function Build-GerberSearchableBranchNewScope {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$DesiredBranchList,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$CurrentBranches,

        [Parameter(Mandatory)]
        [string]$Mode,

        [AllowEmptyString()]
        [string]$DefaultBranch = ''
    )

    if ($Mode -ne 'Merge') {
        $scope = @($DesiredBranchList)
    } else {
        $scope = @(Get-GerberMergedSearchableBranchScope -DesiredBranches $DesiredBranchList -CurrentBranches $CurrentBranches)
    }
    return [string[]]@(Get-GerberExplicitBranchScope -Scope $scope -DefaultBranch $DefaultBranch)
}

function Get-GerberExplicitBranchScope {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Scope,

        [AllowEmptyString()]
        [string]$DefaultBranch
    )

    if ([string]::IsNullOrEmpty($DefaultBranch)) { return [string[]]@($Scope) }
    return [string[]]@($Scope | Where-Object { -not [string]::Equals($_, $DefaultBranch, [System.StringComparison]::OrdinalIgnoreCase) })
}

function Get-GerberMergedSearchableBranchScope {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$DesiredBranches,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$CurrentBranches
    )

    $desiredSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($b in $DesiredBranches) { $null = $desiredSet.Add($b) }
    $merged = [System.Collections.Generic.List[string]]::new()
    foreach ($b in $DesiredBranches) { $null = $merged.Add($b) }
    foreach ($b in $CurrentBranches) {
        if (-not $desiredSet.Contains($b)) { $null = $merged.Add($b) }
    }
    return [string[]]@($merged)
}

function Test-GerberSearchableBranchScopeAligned {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$NewScope,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$CurrentScope
    )

    if ($NewScope.Count -ne $CurrentScope.Count) { return $false }
    $currentSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($b in $CurrentScope) { $null = $currentSet.Add($b) }
    foreach ($b in $NewScope) {
        if (-not $currentSet.Contains($b)) { return $false }
    }
    return $true
}
