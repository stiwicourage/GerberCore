function Resolve-GerberAdoProjectScope {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [switch]$PreferName
    )

    $project = Get-GerberAdoSelectedProjectOrNull -Context $Context
    if ($null -eq $project) { return [string]$Context.Configuration.ProjectName }

    $preferredValue = if ($PreferName) {
        Get-GerberAdoSelectedProjectName -Project $project
    } else {
        Get-GerberAdoSelectedProjectId -Project $project
    }
    if (-not [string]::IsNullOrWhiteSpace($preferredValue)) { return $preferredValue }

    $fallbackValue = if ($PreferName) {
        Get-GerberAdoSelectedProjectId -Project $project
    } else {
        Get-GerberAdoSelectedProjectName -Project $project
    }
    if (-not [string]::IsNullOrWhiteSpace($fallbackValue)) { return $fallbackValue }

    throw [System.InvalidOperationException]::new(
        'Azure DevOps project selection is missing both Id and Name.'
    )
}

function Get-GerberAdoSelectedProjectOrNull {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context
    )

    if (-not $Context.PSObject.Properties['Project']) { return $null }
    return $Context.Project
}

function Get-GerberAdoSelectedProjectId {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Project
    )

    if (-not $Project.PSObject.Properties['Id']) { return '' }
    return [string]$Project.Id
}

function Get-GerberAdoSelectedProjectName {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Project
    )

    if (-not $Project.PSObject.Properties['Name']) { return '' }
    return [string]$Project.Name
}
