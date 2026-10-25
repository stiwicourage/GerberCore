function Resolve-GerberAdoPullRequestReference {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InputText,

        [Parameter(Mandatory)]
        [pscustomobject]$Configuration
    )

    $trimmedInput = $InputText.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmedInput)) {
        throw [System.ArgumentException]::new('Enter a pull request number like 18075 or a full Azure DevOps pull request URL.')
    }

    if ($trimmedInput -match '^\d+$') {
        return [pscustomobject]@{
            PullRequestId = [int]$trimmedInput
            ProjectName = $Configuration.ProjectName
            RepositoryName = $null
            SourceText = $trimmedInput
        }
    }

    return ConvertTo-GerberAdoPullRequestReferenceFromUrl -InputText $trimmedInput -Configuration $Configuration
}

function ConvertTo-GerberAdoPullRequestReferenceFromUrl {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InputText,

        [Parameter(Mandatory)]
        [pscustomobject]$Configuration
    )

    $resolvedUri = $null
    if (-not [System.Uri]::TryCreate($InputText, [System.UriKind]::Absolute, [ref]$resolvedUri)) {
        throw [System.ArgumentException]::new('Enter a pull request number like 18075 or a full Azure DevOps pull request URL.')
    }

    $parserArguments = @{
        Url = $InputText
    }
    $deploymentType = Get-GerberConfiguredAdoDeploymentType -Configuration $Configuration
    if (-not [string]::IsNullOrWhiteSpace($deploymentType)) {
        $parserArguments.DeploymentType = $deploymentType
    }

    $serverUri = Get-GerberConfiguredAdoServerUri -Configuration $Configuration
    if ($null -ne $serverUri) {
        $parserArguments.ServerUri = $serverUri
    }

    $projectReference = Resolve-GerberAdoProjectUrl @parserArguments
    Assert-GerberAdoPullRequestUrlMatchesConnection -ProjectReference $projectReference -Configuration $Configuration

    $segmentList = @(Get-GerberAdoPullRequestUrlSegmentList -ResolvedUri $resolvedUri)
    $projectSegmentList = @(Get-GerberAdoPullRequestUrlSegmentList -ResolvedUri $projectReference.ProjectUri)
    $relativeSegmentList = @(Get-GerberAdoRemainingPathSegmentList `
            -SegmentList $segmentList `
            -PrefixLength $projectSegmentList.Count)
    $gitIndex = Assert-GerberAdoPullRequestUrlPath -SegmentList $relativeSegmentList -Configuration $Configuration

    $pullRequestIdText = Get-GerberAdoPullRequestIdText -SegmentList $relativeSegmentList -GitIndex $gitIndex -InputText $InputText

    return [pscustomobject]@{
        PullRequestId = [int]$pullRequestIdText
        ProjectName = $projectReference.Project
        RepositoryName = $relativeSegmentList[$gitIndex + 1]
        SourceText = $InputText
    }
}

function Assert-GerberAdoPullRequestUrlMatchesConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$ProjectReference,

        [Parameter(Mandatory)]
        [pscustomobject]$Configuration
    )

    $configuredServerUri = Get-GerberConfiguredAdoServerUri -Configuration $Configuration
    if ((Get-GerberAdoNormalizedUriText -ResolvedUri $ProjectReference.ServerUri) -ne (Get-GerberAdoNormalizedUriText -ResolvedUri $configuredServerUri)) {
        throw [System.ArgumentException]::new(
            "Gerber can only review pull request URLs under '$($configuredServerUri.AbsoluteUri)'."
        )
    }

    $configuredCollectionName = [string]$Configuration.CollectionName
    $resolvedCollectionName = if ($ProjectReference.DeploymentType -eq 'Services') {
        $ProjectReference.Organization
    } else {
        $ProjectReference.Collection
    }

    if (-not $resolvedCollectionName.Equals($configuredCollectionName, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw [System.ArgumentException]::new(
            "Gerber can only review pull request URLs in collection '$configuredCollectionName'."
        )
    }
}

function Get-GerberAdoPullRequestUrlSegmentList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$ResolvedUri
    )

    return @(
        foreach ($segment in $ResolvedUri.AbsolutePath.Trim('/').Split('/')) {
            if (-not [string]::IsNullOrWhiteSpace($segment)) {
                [System.Uri]::UnescapeDataString($segment)
            }
        }
    )
}

function Assert-GerberAdoPullRequestUrlPath {
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$SegmentList,

        [Parameter(Mandatory)]
        [pscustomobject]$Configuration
    )

    $gitIndex = [Array]::IndexOf($SegmentList, '_git')
    $isMissingGitPath = ($gitIndex -lt 0) -or ($SegmentList.Count -lt ($gitIndex + 3))
    if ($isMissingGitPath) {
        throw [System.ArgumentException]::new((Get-GerberAdoPullRequestUrlGuidance -Configuration $Configuration))
    }

    $hasPullRequestSegment = $SegmentList[$gitIndex + 2].ToLowerInvariant() -eq 'pullrequest'
    $hasPullRequestIdSegment = $SegmentList.Count -ge ($gitIndex + 4)
    if ((-not $hasPullRequestSegment) -or (-not $hasPullRequestIdSegment)) {
        throw [System.ArgumentException]::new((Get-GerberAdoPullRequestUrlGuidance -Configuration $Configuration))
    }

    return $gitIndex
}

function Get-GerberAdoPullRequestUrlGuidance {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration
    )

    $collectionText = ([string]$Configuration.CollectionUri.AbsoluteUri).TrimEnd('/')
    return "Enter a full Azure DevOps pull request URL in the form $collectionText/<project>/_git/<repo>/pullrequest/<id>."
}

function Get-GerberConfiguredAdoDeploymentType {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration
    )

    if ($Configuration.PSObject.Properties.Match('DeploymentType').Count -eq 0) {
        return ''
    }

    return [string]$Configuration.DeploymentType
}

function Get-GerberConfiguredAdoServerUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration
    )

    if ($Configuration.PSObject.Properties.Match('ServerUri').Count -gt 0 -and $null -ne $Configuration.ServerUri) {
        return [uri]$Configuration.ServerUri
    }

    if ($Configuration.PSObject.Properties.Match('ServerUrl').Count -gt 0 -and $null -ne $Configuration.ServerUrl) {
        return [uri]$Configuration.ServerUrl
    }

    return $null
}

function Get-GerberAdoNormalizedUriText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$ResolvedUri
    )

    return $ResolvedUri.AbsoluteUri.TrimEnd('/')
}

function Get-GerberAdoPullRequestIdText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$SegmentList,

        [Parameter(Mandatory)]
        [int]$GitIndex,

        [Parameter(Mandatory)]
        [string]$InputText
    )

    $pullRequestIdText = $SegmentList[$GitIndex + 3]
    if ($pullRequestIdText -notmatch '^\d+$') {
        throw [System.ArgumentException]::new("Gerber could not read a numeric pull request ID from '$InputText'.")
    }

    return $pullRequestIdText
}
