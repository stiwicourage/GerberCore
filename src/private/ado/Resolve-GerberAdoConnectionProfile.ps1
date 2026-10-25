function Resolve-GerberAdoConnectionProfile {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [string]$Name
    )

    $configuration = Get-GerberUserConfiguration
    $connectionProfile = if ($PSBoundParameters.ContainsKey('Name')) {
        Get-GerberAdoConnectionProfile -Name $Name -Configuration $configuration
    } else {
        Get-GerberDefaultAdoConnectionProfile -Configuration $configuration
    }

    if ($null -eq $connectionProfile) {
        $configPath = Resolve-GerberUserConfigPath
        if ($PSBoundParameters.ContainsKey('Name')) {
            throw [System.ArgumentException]::new(
                "Gerber Azure DevOps profile '$Name' was not found in user configuration file '$configPath'."
            )
        }

        throw [System.ArgumentException]::new(
            "Gerber Azure DevOps configuration file '$configPath' does not define 'ado.defaultProfile'. Configure an Azure DevOps profile and set it as the default."
        )
    }

    $parserArguments = @{
        Url = $connectionProfile.ProjectUrl
    }
    if (-not [string]::IsNullOrWhiteSpace($connectionProfile.DeploymentType)) {
        $parserArguments.DeploymentType = $connectionProfile.DeploymentType.Trim()
    }

    if (-not [string]::IsNullOrWhiteSpace($connectionProfile.ServerUrl)) {
        $parserArguments.ServerUri = [uri]$connectionProfile.ServerUrl.Trim()
    }

    $resolvedProfile = Resolve-GerberAdoProjectUrl @parserArguments
    return [pscustomobject][ordered]@{
        ProfileName    = $connectionProfile.Name
        DeploymentType = $resolvedProfile.DeploymentType
        ServerUri      = $resolvedProfile.ServerUri
        Organization   = $resolvedProfile.Organization
        Collection     = $resolvedProfile.Collection
        Project        = $resolvedProfile.Project
        ProjectUri     = $resolvedProfile.ProjectUri
    }
}

function Get-GerberDefaultAdoConnectionProfile {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Configuration
    )

    $adoConfiguration = Get-GerberUserConfigurationPropertyValue -Configuration $Configuration -PropertyName 'ado'
    if ($null -eq $adoConfiguration) {
        return $null
    }

    $defaultProfileName = Get-GerberUserConfigurationPropertyValue -Configuration $adoConfiguration -PropertyName 'defaultProfile'
    if (($defaultProfileName -isnot [string]) -or [string]::IsNullOrWhiteSpace($defaultProfileName)) {
        return $null
    }

    return Get-GerberAdoConnectionProfile -Name $defaultProfileName -Configuration $Configuration
}
