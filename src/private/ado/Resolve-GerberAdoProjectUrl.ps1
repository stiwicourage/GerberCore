function Resolve-GerberAdoProjectUrl {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Url,

        [ValidateSet('Services', 'Server')]
        [string]$DeploymentType,

        [uri]$ServerUri,

        [switch]$AllowInsecureHttp
    )

    $trimmedUrl = Get-GerberTrimmedRequiredText `
        -Value $Url `
        -Message 'Provide a full Azure DevOps project URL.'
    Assert-GerberAdoProjectUrlPercentEncoding -Url $trimmedUrl

    $resolvedUri = ConvertTo-GerberAdoAbsoluteUri -Url $trimmedUrl
    Assert-GerberAdoProjectUrlAuthority -ResolvedUri $resolvedUri

    $segmentList = @(Get-GerberAdoUrlPathSegmentList -ResolvedUri $resolvedUri)
    $servicesHostKind = Get-GerberAdoServicesHostKind -HostName $resolvedUri.Host
    $effectiveDeploymentType = Get-GerberAdoProjectUrlDeploymentType `
        -ServicesHostKind $servicesHostKind `
        -RequestedDeploymentType $DeploymentType `
        -ServerUri $ServerUri
    Assert-GerberAdoProjectUrlScheme `
        -ResolvedUri $resolvedUri `
        -DeploymentType $effectiveDeploymentType `
        -AllowInsecureHttp:$AllowInsecureHttp

    if ($effectiveDeploymentType -eq 'Services') {
        if ($servicesHostKind -eq 'Modern') {
            return Resolve-GerberAdoModernServicesProjectUrl -ResolvedUri $resolvedUri -SegmentList $segmentList
        }

        return Resolve-GerberAdoLegacyServicesProjectUrl -ResolvedUri $resolvedUri -SegmentList $segmentList
    }

    if ($ServerUri) {
        return Resolve-GerberAdoExplicitServerProjectUrl `
            -ResolvedUri $resolvedUri `
            -SegmentList $segmentList `
            -ServerUri $ServerUri
    }

    return Resolve-GerberAdoInferredServerProjectUrl -ResolvedUri $resolvedUri -SegmentList $segmentList
}

function Get-GerberTrimmedRequiredText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw [System.ArgumentException]::new($Message)
    }

    return $Value.Trim()
}

function Assert-GerberAdoProjectUrlPercentEncoding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Url
    )

    if ($Url -match '%(?![0-9A-Fa-f]{2})') {
        throw [System.ArgumentException]::new(
            "Azure DevOps project URL '$Url' contains malformed percent-encoding."
        )
    }
}

function ConvertTo-GerberAdoAbsoluteUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Url
    )

    $resolvedUri = $null
    if (-not [System.Uri]::TryCreate($Url, [System.UriKind]::Absolute, [ref]$resolvedUri)) {
        throw [System.ArgumentException]::new(
            "Provide a full Azure DevOps project URL such as 'https://dev.azure.com/<organization>/<project>'."
        )
    }

    if ($resolvedUri.Scheme -eq 'file') {
        throw [System.ArgumentException]::new(
            "Provide a full Azure DevOps project URL such as 'https://dev.azure.com/<organization>/<project>'."
        )
    }

    return $resolvedUri
}

function Assert-GerberAdoProjectUrlAuthority {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$ResolvedUri
    )

    if ([string]::IsNullOrWhiteSpace($ResolvedUri.Host)) {
        throw [System.ArgumentException]::new('Azure DevOps project URL must include a hostname.')
    }

    if (-not [string]::IsNullOrWhiteSpace($ResolvedUri.UserInfo)) {
        throw [System.ArgumentException]::new(
            'Azure DevOps project URLs must not contain embedded credentials.'
        )
    }
}

function Get-GerberAdoUrlPathSegmentList {
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

function Get-GerberAdoProjectUrlDeploymentType {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$ServicesHostKind,

        [AllowEmptyString()]
        [string]$RequestedDeploymentType,

        [AllowNull()]
        [uri]$ServerUri
    )

    if ($ServerUri -and ($RequestedDeploymentType -ne 'Server')) {
        throw [System.ArgumentException]::new(
            'ServerUri can only be used together with DeploymentType Server.'
        )
    }

    if (-not [string]::IsNullOrWhiteSpace($ServicesHostKind)) {
        if ($RequestedDeploymentType -eq 'Server') {
            throw [System.ArgumentException]::new(
                'Azure DevOps Services URLs cannot be parsed as DeploymentType Server.'
            )
        }

        return 'Services'
    }

    if ($RequestedDeploymentType -eq 'Services') {
        throw [System.ArgumentException]::new(
            'DeploymentType Services requires a dev.azure.com or *.visualstudio.com URL.'
        )
    }

    return 'Server'
}

function Assert-GerberAdoProjectUrlScheme {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$ResolvedUri,

        [Parameter(Mandatory)]
        [ValidateSet('Services', 'Server')]
        [string]$DeploymentType,

        [switch]$AllowInsecureHttp
    )

    switch ($ResolvedUri.Scheme) {
        'https' { return }
        'http' {
            if ($DeploymentType -eq 'Services') {
                throw [System.ArgumentException]::new('Azure DevOps Services URLs must use HTTPS.')
            }

            if (-not $AllowInsecureHttp) {
                throw [System.ArgumentException]::new(
                    'Azure DevOps Server URLs must use HTTPS unless AllowInsecureHttp is specified.'
                )
            }

            return
        }
        default {
            throw [System.ArgumentException]::new(
                "Azure DevOps project URL scheme '$($ResolvedUri.Scheme)' is not supported."
            )
        }
    }
}

function Get-GerberAdoServicesHostKind {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$HostName
    )

    if ($HostName.Equals('dev.azure.com', [System.StringComparison]::OrdinalIgnoreCase)) {
        return 'Modern'
    }

    if ($HostName.EndsWith('.visualstudio.com', [System.StringComparison]::OrdinalIgnoreCase)) {
        return 'Legacy'
    }

    return ''
}

function Resolve-GerberAdoModernServicesProjectUrl {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$ResolvedUri,

        [Parameter(Mandatory)]
        [string[]]$SegmentList
    )

    if ($SegmentList.Count -lt 2) {
        throw [System.ArgumentException]::new(
            'Azure DevOps Services URLs must include both organization and project.'
        )
    }

    $organization = Get-GerberTrimmedRequiredText `
        -Value $SegmentList[0] `
        -Message 'Azure DevOps Services URL is missing the organization segment.'
    $project = Get-GerberTrimmedRequiredText `
        -Value $SegmentList[1] `
        -Message 'Azure DevOps Services URL is missing the project segment.'
    Assert-GerberAdoProjectResourcePath -SegmentList $SegmentList -RootSegmentCount 2

    return ConvertTo-GerberAdoProjectUrlResult -Option ([pscustomobject]@{
            ResolvedUri = $ResolvedUri
            DeploymentType = 'Services'
            ServerPathSegmentList = @()
            Organization = $organization
            Collection = $null
            Project = $project
            ProjectPathSegmentList = @($organization, $project)
        })
}

function Resolve-GerberAdoLegacyServicesProjectUrl {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$ResolvedUri,

        [Parameter(Mandatory)]
        [string[]]$SegmentList
    )

    $organization = Get-GerberAdoLegacyServicesOrganization -HostName $ResolvedUri.Host
    if ($SegmentList.Count -lt 1) {
        throw [System.ArgumentException]::new(
            'Azure DevOps Services legacy URLs must include a project path.'
        )
    }

    $projectSegmentIndex = 0
    if ($SegmentList[0].Equals('DefaultCollection', [System.StringComparison]::OrdinalIgnoreCase)) {
        if ($SegmentList.Count -lt 2) {
            throw [System.ArgumentException]::new(
                'Azure DevOps Services legacy URL is missing the project segment.'
            )
        }

        $projectSegmentIndex = 1
    }

    $project = Get-GerberTrimmedRequiredText `
        -Value $SegmentList[$projectSegmentIndex] `
        -Message 'Azure DevOps Services legacy URL is missing the project segment.'
    Assert-GerberAdoProjectResourcePath `
        -SegmentList $SegmentList `
        -RootSegmentCount ($projectSegmentIndex + 1)

    return ConvertTo-GerberAdoProjectUrlResult -Option ([pscustomobject]@{
            ResolvedUri = $ResolvedUri
            DeploymentType = 'Services'
            ServerPathSegmentList = @()
            Organization = $organization
            Collection = $null
            Project = $project
            ProjectPathSegmentList = @($SegmentList[0..$projectSegmentIndex])
        })
}

function Get-GerberAdoLegacyServicesOrganization {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$HostName
    )

    $organization = $HostName -replace '(?i)\.visualstudio\.com$'
    return Get-GerberTrimmedRequiredText `
        -Value $organization `
        -Message 'Azure DevOps Services legacy URL is missing the organization host segment.'
}

function Resolve-GerberAdoInferredServerProjectUrl {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$ResolvedUri,

        [Parameter(Mandatory)]
        [string[]]$SegmentList
    )

    if ($SegmentList.Count -lt 2) {
        throw [System.ArgumentException]::new(
            'Azure DevOps Server URLs must include both collection and project.'
        )
    }

    if (($SegmentList.Count -eq 2) -and
        $SegmentList[0].Equals('tfs', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw [System.ArgumentException]::new(
            'Azure DevOps Server URLs must include both collection and project.'
        )
    }

    if (($SegmentList.Count -gt 2) -and
        (-not $SegmentList[0].Equals('tfs', [System.StringComparison]::OrdinalIgnoreCase))) {
        throw [System.ArgumentException]::new(
            "Gerber could not determine the Azure DevOps Server root from '$($ResolvedUri.AbsoluteUri)'. Re-run with DeploymentType Server and ServerUri set to the server root."
        )
    }

    $serverPathSegmentList = @()
    $projectStartIndex = 0
    if ($SegmentList.Count -gt 2) {
        $serverPathSegmentList = @($SegmentList[0])
        $projectStartIndex = 1
    }

    return ConvertTo-GerberAdoServerProjectUrlResult `
        -ResolvedUri $ResolvedUri `
        -ServerPathSegmentList $serverPathSegmentList `
        -ProjectSegmentList @($SegmentList[$projectStartIndex..($SegmentList.Count - 1)])
}

function Resolve-GerberAdoExplicitServerProjectUrl {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$ResolvedUri,

        [Parameter(Mandatory)]
        [string[]]$SegmentList,

        [Parameter(Mandatory)]
        [uri]$ServerUri
    )

    Assert-GerberAdoProjectUrlAuthority -ResolvedUri $ServerUri
    Assert-GerberAdoServerUriRoot -ServerUri $ServerUri

    if (-not (Test-GerberAdoUriAuthorityMatch -Left $ResolvedUri -Right $ServerUri)) {
        throw [System.ArgumentException]::new(
            "The URL '$($ResolvedUri.AbsoluteUri)' does not belong to the explicit Azure DevOps Server root '$($ServerUri.AbsoluteUri)'."
        )
    }

    $serverPathSegmentList = @(Get-GerberAdoUrlPathSegmentList -ResolvedUri $ServerUri)
    if (-not (Test-GerberAdoPathPrefix -SegmentList $SegmentList -PrefixList $serverPathSegmentList)) {
        throw [System.ArgumentException]::new(
            "The URL '$($ResolvedUri.AbsoluteUri)' does not belong to the explicit Azure DevOps Server root '$($ServerUri.AbsoluteUri)'."
        )
    }

    $projectSegmentList = @(Get-GerberAdoRemainingPathSegmentList `
            -SegmentList $SegmentList `
            -PrefixLength $serverPathSegmentList.Count)
    return ConvertTo-GerberAdoServerProjectUrlResult `
        -ResolvedUri $ResolvedUri `
        -ServerPathSegmentList $serverPathSegmentList `
        -ProjectSegmentList $projectSegmentList
}

function Assert-GerberAdoServerUriRoot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$ServerUri
    )

    if (-not [string]::IsNullOrWhiteSpace($ServerUri.Query) -or
        -not [string]::IsNullOrWhiteSpace($ServerUri.Fragment)) {
        throw [System.ArgumentException]::new(
            'ServerUri must not contain a query string or fragment.'
        )
    }
}

function Test-GerberAdoUriAuthorityMatch {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$Left,

        [Parameter(Mandatory)]
        [uri]$Right
    )

    return ($Left.Scheme -eq $Right.Scheme) -and
        ($Left.Host -eq $Right.Host) -and
        (Get-GerberAdoEffectivePort -ResolvedUri $Left) -eq (Get-GerberAdoEffectivePort -ResolvedUri $Right)
}

function Get-GerberAdoEffectivePort {
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$ResolvedUri
    )

    if ($ResolvedUri.IsDefaultPort) {
        return -1
    }

    return $ResolvedUri.Port
}

function Test-GerberAdoPathPrefix {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$SegmentList,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$PrefixList
    )

    if ($PrefixList.Count -gt $SegmentList.Count) {
        return $false
    }

    for ($index = 0; $index -lt $PrefixList.Count; $index++) {
        if (-not $SegmentList[$index].Equals($PrefixList[$index], [System.StringComparison]::OrdinalIgnoreCase)) {
            return $false
        }
    }

    return $true
}

function Get-GerberAdoRemainingPathSegmentList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$SegmentList,

        [Parameter(Mandatory)]
        [int]$PrefixLength
    )

    if ($PrefixLength -ge $SegmentList.Count) {
        return @()
    }

    return @($SegmentList[$PrefixLength..($SegmentList.Count - 1)])
}

function ConvertTo-GerberAdoServerProjectUrlResult {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$ResolvedUri,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$ServerPathSegmentList,

        [Parameter(Mandatory)]
        [string[]]$ProjectSegmentList
    )

    if ($ProjectSegmentList.Count -lt 2) {
        throw [System.ArgumentException]::new(
            'Azure DevOps Server URLs must include both collection and project.'
        )
    }

    $collection = Get-GerberTrimmedRequiredText `
        -Value $ProjectSegmentList[0] `
        -Message 'Azure DevOps Server URL is missing the collection segment.'
    $project = Get-GerberTrimmedRequiredText `
        -Value $ProjectSegmentList[1] `
        -Message 'Azure DevOps Server URL is missing the project segment.'
    Assert-GerberAdoProjectResourcePath -SegmentList $ProjectSegmentList -RootSegmentCount 2

    return ConvertTo-GerberAdoProjectUrlResult -Option ([pscustomobject]@{
            ResolvedUri = $ResolvedUri
            DeploymentType = 'Server'
            ServerPathSegmentList = $ServerPathSegmentList
            Organization = $null
            Collection = $collection
            Project = $project
            ProjectPathSegmentList = @($ServerPathSegmentList + $ProjectSegmentList[0..1])
        })
}

function Assert-GerberAdoProjectResourcePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$SegmentList,

        [Parameter(Mandatory)]
        [int]$RootSegmentCount
    )

    if ($SegmentList.Count -le $RootSegmentCount) {
        return
    }

    $resourceSegment = $SegmentList[$RootSegmentCount]
    if (Test-GerberAdoRecognizedProjectResourceSegment -Segment $resourceSegment) {
        return
    }

    throw [System.ArgumentException]::new(
        "Azure DevOps URL path '$resourceSegment' does not identify a supported project resource. Use a project URL or a recognized project resource path such as _git, _build, or _boards."
    )
}

function Test-GerberAdoRecognizedProjectResourceSegment {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Segment
    )

    return @(
        '_apps'
        '_backlogs'
        '_boards'
        '_build'
        '_dashboards'
        '_git'
        '_packaging'
        '_queries'
        '_releaseProgress'
        '_settings'
        '_sprints'
        '_testManagement'
        '_testmanagement'
        '_wiki'
        '_workitems'
    ) -contains $Segment
}

function ConvertTo-GerberAdoProjectUrlResult {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Option
    )

    return [pscustomobject][ordered]@{
        DeploymentType = $Option.DeploymentType
        ServerUri      = ConvertTo-GerberAdoNormalizedUri `
            -ResolvedUri $Option.ResolvedUri `
            -PathSegmentList $Option.ServerPathSegmentList
        Organization   = $Option.Organization
        Collection     = $Option.Collection
        Project        = $Option.Project
        ProjectUri     = ConvertTo-GerberAdoNormalizedUri `
            -ResolvedUri $Option.ResolvedUri `
            -PathSegmentList $Option.ProjectPathSegmentList
    }
}

function ConvertTo-GerberAdoNormalizedUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$ResolvedUri,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$PathSegmentList
    )

    $uriBuilder = [System.UriBuilder]::new($ResolvedUri)
    $uriBuilder.Path = Get-GerberAdoNormalizedPath -PathSegmentList $PathSegmentList
    $uriBuilder.Query = ''
    $uriBuilder.Fragment = ''
    $uriBuilder.Port = Get-GerberAdoEffectivePort -ResolvedUri $ResolvedUri
    return $uriBuilder.Uri
}

function Get-GerberAdoNormalizedPath {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$PathSegmentList
    )

    if ($PathSegmentList.Count -eq 0) {
        return '/'
    }

    return '/' + (@(
            foreach ($segment in $PathSegmentList) {
                [System.Uri]::EscapeDataString($segment)
            }
        ) -join '/')
}
