function Get-GerberAdoBranchSearchResult {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [string]$NormalizedBranchPath
    )

    $repoList = @(Get-GerberAdoRepositoryList -Configuration $Configuration -Pat $Pat)
    $context = [pscustomobject]@{
        Configuration = $Configuration
        Pat = $Pat
        BranchPath = $NormalizedBranchPath
    }
    $scanResult = Invoke-GerberAdoBranchRepositoryScan -Context $context -RepoList $repoList
    return [pscustomobject]@{
        NormalizedBranchPath = $NormalizedBranchPath
        Total = $repoList.Count
        FoundList = $scanResult.FoundList
        FailedList = $scanResult.FailedList
    }
}

function Invoke-GerberAdoBranchRepositoryScan {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$RepoList
    )

    $foundList = [System.Collections.Generic.List[string]]::new()
    $failedList = [System.Collections.Generic.List[string]]::new()
    $total = $RepoList.Count
    $index = 0
    foreach ($repo in $RepoList) {
        $index++
        Write-GerberProgressBar -Current $index -Total $total -Prefix 'Scanning repositories...'
        $item = Get-GerberAdoBranchRepoScanItem -Context $Context -Repo $repo
        if ($item.Found) { $null = $foundList.Add($repo.Name) }
        if ($item.Failed) { $null = $failedList.Add($repo.Name) }
    }
    return [pscustomobject]@{ FoundList = @($foundList); FailedList = @($failedList) }
}

function Get-GerberAdoBranchRepoScanItem {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [pscustomobject]$Repo
    )

    try {
        $found = Test-GerberAdoRepoBranchPresence `
            -Configuration $Context.Configuration `
            -Pat $Context.Pat `
            -RepoId $Repo.Id `
            -BranchPath $Context.BranchPath
        return [pscustomobject]@{ Found = $found; Failed = $false }
    } catch {
        return [pscustomobject]@{ Found = $false; Failed = $true }
    }
}

function Test-GerberAdoRepoBranchPresence {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [string]$RepoId,

        [Parameter(Mandatory)]
        [string]$BranchPath
    )

    $filterValue = Get-GerberAdoBranchRefFilterValue -NormalizedBranchPath $BranchPath
    $relPath = "$($Configuration.ProjectName)/_apis/git/repositories/$RepoId/refs"
    $uri = Get-GerberAdoBranchRequestUri -Configuration $Configuration -RelativePath $relPath -Filter $filterValue
    $response = Invoke-GerberAdoRestRequest `
        -Uri $uri `
        -Pat $Pat `
        -RequestLabel "branch in repository $RepoId" `
        -CredentialIdentifier $Configuration.CredentialIdentifier
    return @(Get-GerberAdoResponseValueList -Response $response).Count -gt 0
}

function Get-GerberAdoRepositoryList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat
    )

    $relPath = "$($Configuration.ProjectName)/_apis/git/repositories"
    $uri = Get-GerberAdoBranchRequestUri -Configuration $Configuration -RelativePath $relPath
    $response = Invoke-GerberAdoRestRequest `
        -Uri $uri `
        -Pat $Pat `
        -RequestLabel 'repositories' `
        -CredentialIdentifier $Configuration.CredentialIdentifier
    return @(
        Get-GerberAdoResponseValueList -Response $response |
            Where-Object { -not $_.isDisabled } |
            ForEach-Object { [pscustomobject]@{ Id = [string]$_.id; Name = [string]$_.name; DefaultBranch = [string]$_.defaultBranch } }
    )
}

function Get-GerberAdoBranchRequestUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$RelativePath,

        [string]$Filter = ''
    )

    $queryMap = [ordered]@{ 'api-version' = $Configuration.DefaultApiVersion }
    if (-not [string]::IsNullOrWhiteSpace($Filter)) {
        $queryMap['filter'] = $Filter
    }
    return Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($Configuration.CollectionUri, $RelativePath)) `
        -QueryParameterMap $queryMap
}

function Get-GerberAdoBranchRefFilterValue {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$NormalizedBranchPath
    )

    $prefix = 'refs/'
    if ($NormalizedBranchPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $NormalizedBranchPath.Substring($prefix.Length)
    }
    return $NormalizedBranchPath
}
