function Get-GerberAdoConnectionProfile {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [string]$Name,

        [AllowNull()]
        [object]$Configuration = $null
    )

    if ($null -eq $Configuration) {
        $Configuration = Get-GerberUserConfiguration
    }

    $adoConfiguration = Get-GerberUserConfigurationPropertyValue -Configuration $Configuration -PropertyName 'ado'
    if ($null -eq $adoConfiguration) {
        return (Select-GerberAdoConnectionProfile `
                -Name $Name `
                -ProfileList @() `
                -HasExplicitName:$PSBoundParameters.ContainsKey('Name'))
    }

    $profileTable = Get-GerberUserConfigurationPropertyValue -Configuration $adoConfiguration -PropertyName 'profiles'
    if ($null -eq $profileTable) {
        return (Select-GerberAdoConnectionProfile `
                -Name $Name `
                -ProfileList @() `
                -HasExplicitName:$PSBoundParameters.ContainsKey('Name'))
    }

    $profileList = @(
        foreach ($profileEntry in @(Get-GerberAdoConfigurationEntry -Configuration $profileTable)) {
            $propertyMap = Copy-GerberAdoProfilePropertyMap -ProfileValue $profileEntry.Value
            [pscustomobject][ordered]@{
                Name           = $profileEntry.Name
                ProjectUrl     = [string]$propertyMap['projectUrl']
                DeploymentType = Get-GerberAdoProfilePropertyText -PropertyMap $propertyMap -PropertyName 'deploymentType'
                ServerUrl      = Get-GerberAdoProfilePropertyText -PropertyMap $propertyMap -PropertyName 'serverUrl'
                PropertyMap    = $propertyMap
            }
        }
    )

    return (Select-GerberAdoConnectionProfile `
            -Name $Name `
            -ProfileList $profileList `
            -HasExplicitName:$PSBoundParameters.ContainsKey('Name'))
}

function Select-GerberAdoConnectionProfile {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$ProfileList,

        [Parameter(Mandatory)]
        [bool]$HasExplicitName
    )

    if (-not $HasExplicitName) {
        return $ProfileList
    }

    Assert-GerberAdoConnectionProfileLookupName -Name $Name
    foreach ($connectionProfile in $ProfileList) {
        if ($connectionProfile.Name.Equals($Name, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $connectionProfile
        }
    }

    return $null
}

function Assert-GerberAdoConnectionProfileLookupName {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Name
    )

    if ($null -eq $Name -or $Name.Length -eq 0) {
        throw [System.ArgumentException]::new('Gerber Azure DevOps profile names must not be empty.')
    }

    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw [System.ArgumentException]::new('Gerber Azure DevOps profile names must not be whitespace only.')
    }

    if ($Name -ne $Name.Trim()) {
        throw [System.ArgumentException]::new(
            "Gerber Azure DevOps profile name '$Name' must not contain leading or trailing whitespace."
        )
    }

    if ($Name -match '[\x00-\x1F]') {
        throw [System.ArgumentException]::new(
            "Gerber Azure DevOps profile name '$Name' must not contain control characters."
        )
    }
}

function Copy-GerberAdoProfilePropertyMap {
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$ProfileValue
    )

    $propertyMap = [ordered]@{}
    foreach ($propertyEntry in @(Get-GerberAdoConfigurationEntry -Configuration $ProfileValue)) {
        $propertyMap[$propertyEntry.Name] = $propertyEntry.Value
    }

    return $propertyMap
}

function Get-GerberAdoProfilePropertyText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$PropertyMap,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    foreach ($key in $PropertyMap.Keys) {
        if (-not [string]::Equals([string]$key, $PropertyName, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        if ($null -eq $PropertyMap[$key]) {
            return ''
        }

        return [string]$PropertyMap[$key]
    }

    return ''
}
