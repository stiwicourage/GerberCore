function Get-GerberAdoDefaultBranchReport {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context
    )

    $repoList = @(Get-GerberAdoRepositoryList -Configuration $Context.Configuration -Pat $Context.Pat)
    $scanResult = Invoke-GerberDefaultBranchRepoScan -Context $Context -RepoList $repoList
    Write-GerberPromptTrace -EventName 'set-default-scan' -Data @{
        Total         = $repoList.Count
        ToUpdateCount = $scanResult.ToUpdateList.Count
        AlignedCount  = $scanResult.AlignedList.Count
        NotFoundCount = $scanResult.NotFoundList.Count
    }
    return [pscustomobject]@{
        ToUpdateList       = @($scanResult.ToUpdateList)
        AlreadyAlignedList = @($scanResult.AlignedList)
        NotFoundList       = @($scanResult.NotFoundList)
    }
}

function Invoke-GerberDefaultBranchRepoScan {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$RepoList
    )

    $lists = [pscustomobject]@{
        ToUpdateList = [System.Collections.Generic.List[pscustomobject]]::new()
        AlignedList  = [System.Collections.Generic.List[pscustomobject]]::new()
        NotFoundList = [System.Collections.Generic.List[pscustomobject]]::new()
    }
    $total = $RepoList.Count
    $index = 0
    foreach ($repo in $RepoList) {
        $index++
        Write-GerberProgressBar -Current $index -Total $total -Prefix 'Scanning repositories...'
        $item = Get-GerberDefaultBranchPlanItem -Context $Context -Repo $repo
        Add-GerberDefaultBranchPlanItem -Item $item -Lists $lists
    }
    return $lists
}

function Add-GerberDefaultBranchPlanItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Item,

        [Parameter(Mandatory)]
        [pscustomobject]$Lists
    )

    switch ($Item.Classification) {
        'Aligned'  { $null = $Lists.AlignedList.Add([pscustomobject]@{ RepoName = $Item.RepoName }) }
        'ToUpdate' { $null = $Lists.ToUpdateList.Add($Item) }
        'NotFound' { $null = $Lists.NotFoundList.Add([pscustomobject]@{ RepoName = $Item.RepoName }) }
    }
}

function Get-GerberDefaultBranchPlanItem {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [pscustomobject]$Repo
    )

    if ([string]::Equals($Repo.DefaultBranch, $Context.TargetBranch, [System.StringComparison]::OrdinalIgnoreCase)) {
        $classification = 'Aligned'
    } elseif (Test-GerberAdoRepoBranchPresence -Configuration $Context.Configuration -Pat $Context.Pat -RepoId $Repo.Id -BranchPath $Context.TargetBranch) {
        $classification = 'ToUpdate'
    } else {
        $classification = 'NotFound'
    }
    Write-GerberPromptTrace -EventName 'set-default-plan-item' -Data @{
        RepoName       = $Repo.Name
        Classification = $classification
    }
    return [pscustomobject]@{ RepoId = $Repo.Id; RepoName = $Repo.Name; Classification = $classification }
}
