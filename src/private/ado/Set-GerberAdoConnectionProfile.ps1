function Set-GerberAdoConnectionProfile {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$ProjectUrl,

        [string]$DeploymentType,

        [string]$ServerUrl
    )

    Assert-GerberAdoConnectionProfileLookupName -Name $Name

    $configuration = Get-GerberUserConfiguration
    $existingConnectionProfile = Get-GerberAdoConnectionProfile -Name $Name -Configuration $configuration
    $storedProfileName = if ($null -eq $existingConnectionProfile) { $Name } else { $existingConnectionProfile.Name }
    $profileMap = if ($null -eq $existingConnectionProfile) {
        [ordered]@{}
    } else {
        Copy-GerberAdoProfilePropertyMap -ProfileValue $existingConnectionProfile.PropertyMap
    }

    $profileMap = Get-GerberUpdatedAdoProfileMap `
        -ProfileMap $profileMap `
        -UpdateOption ([pscustomobject]@{
                ProfileName       = $storedProfileName
                ProjectUrl        = $ProjectUrl
                DeploymentType    = $DeploymentType
                ServerUrl         = $ServerUrl
                HasDeploymentType = $PSBoundParameters.ContainsKey('DeploymentType')
                HasServerUrl      = $PSBoundParameters.ContainsKey('ServerUrl')
            })

    $candidateConfiguration = Copy-GerberUserConfigurationMap -Configuration $configuration
    $adoConfiguration = Get-GerberOrAddConfigurationSection -Configuration $candidateConfiguration -PropertyName 'ado'
    $profileTable = Get-GerberOrAddConfigurationSection -Configuration $adoConfiguration -PropertyName 'profiles'
    $profileTable[$storedProfileName] = $profileMap
    $null = Test-GerberUserConfiguration -Configuration $candidateConfiguration -Path (Resolve-GerberUserConfigPath)

    if ($PSCmdlet.ShouldProcess($storedProfileName, 'Save Gerber Azure DevOps profile')) {
        Save-GerberUserConfiguration -Configuration $candidateConfiguration
    }

    return Get-GerberAdoConnectionProfile -Name $storedProfileName -Configuration $candidateConfiguration
}

function Get-GerberUpdatedAdoProfileMap {
    [OutputType([System.Collections.IDictionary])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$ProfileMap,

        [Parameter(Mandatory)]
        [pscustomobject]$UpdateOption
    )

    $parserArguments = @{
        Url = $UpdateOption.ProjectUrl
    }
    if ($UpdateOption.HasDeploymentType) {
        $parserArguments.DeploymentType = $UpdateOption.DeploymentType
    }

    if ($UpdateOption.HasServerUrl) {
        $parserArguments.ServerUri = ConvertTo-GerberAdoProfileServerUri `
            -ServerUrl $UpdateOption.ServerUrl `
            -ProfileName $UpdateOption.ProfileName `
            -Path (Resolve-GerberUserConfigPath)
    }

    $resolvedProfile = Resolve-GerberAdoProjectUrl @parserArguments
    $ProfileMap['projectUrl'] = ([string]$resolvedProfile.ProjectUri.AbsoluteUri).TrimEnd('/')
    Complete-GerberAdoOptionalProfileHint `
        -ProfileMap $ProfileMap `
        -PropertyName 'deploymentType' `
        -Value $UpdateOption.DeploymentType `
        -ShouldSet:$UpdateOption.HasDeploymentType
    Complete-GerberAdoOptionalProfileHint `
        -ProfileMap $ProfileMap `
        -PropertyName 'serverUrl' `
        -Value $UpdateOption.ServerUrl `
        -ShouldSet:$UpdateOption.HasServerUrl
    return $ProfileMap
}

function Complete-GerberAdoOptionalProfileHint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$ProfileMap,

        [Parameter(Mandatory)]
        [string]$PropertyName,

        [AllowNull()]
        [string]$Value,

        [Parameter(Mandatory)]
        [bool]$ShouldSet
    )

    if (-not $ShouldSet) {
        $null = $ProfileMap.Remove($PropertyName)
        return
    }

    $ProfileMap[$PropertyName] = if ($null -eq $Value) { '' } else { $Value.Trim() }
}

function Copy-GerberUserConfigurationMap {
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Configuration
    )

    $copied = [ordered]@{}
    foreach ($propertyEntry in @(Get-GerberAdoConfigurationEntry -Configuration $Configuration)) {
        $copied[$propertyEntry.Name] = $propertyEntry.Value
    }

    return $copied
}

function Get-GerberOrAddConfigurationSection {
    [OutputType([System.Collections.IDictionary])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Configuration,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    $section = Get-GerberUserConfigurationPropertyValue -Configuration $Configuration -PropertyName $PropertyName
    if ($section -is [System.Collections.IDictionary]) {
        return $section
    }

    $Configuration[$PropertyName] = [ordered]@{}
    return $Configuration[$PropertyName]
}
