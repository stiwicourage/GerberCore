function Test-GerberAdoUserConfiguration {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Configuration,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $adoConfiguration = Get-GerberUserConfigurationPropertyValue -Configuration $Configuration -PropertyName 'ado'
    if ($null -eq $adoConfiguration) {
        return $true
    }

    Assert-GerberAdoConfigurationRootObject -AdoConfiguration $adoConfiguration -Path $Path
    $resolvedNameMap = Get-GerberAdoResolvedProfileNameMap -AdoConfiguration $adoConfiguration -Path $Path
    Assert-GerberAdoDefaultProfileReference `
        -AdoConfiguration $adoConfiguration `
        -ResolvedNameMap $resolvedNameMap `
        -Path $Path
    return $true
}

function Assert-GerberAdoConfigurationRootObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$AdoConfiguration,

        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-GerberUserConfigurationRootObject -Configuration $AdoConfiguration)) {
        throw [System.IO.InvalidDataException]::new(
            "Gerber user configuration file '$Path' property 'ado' must be a JSON object."
        )
    }
}

function Get-GerberAdoResolvedProfileNameMap {
    [OutputType([System.Collections.Generic.Dictionary[string, string]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$AdoConfiguration,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $profileTable = Get-GerberAdoProfileTable -AdoConfiguration $AdoConfiguration -Path $Path
    $resolvedNameMap = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($profileEntry in @(Get-GerberAdoConfigurationEntry -Configuration $profileTable)) {
        Assert-GerberAdoConnectionProfileName -Name $profileEntry.Name -Path $Path
        Assert-GerberAdoUniqueConnectionProfileName `
            -Name $profileEntry.Name `
            -ResolvedNameMap $resolvedNameMap `
            -Path $Path
        Assert-GerberAdoProfileObject -ProfileValue $profileEntry.Value -ProfileName $profileEntry.Name -Path $Path
        Test-GerberAdoProfileDefinition -ProfileValue $profileEntry.Value -ProfileName $profileEntry.Name -Path $Path
    }

    return $resolvedNameMap
}

function Get-GerberAdoProfileTable {
    [OutputType([object])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$AdoConfiguration,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $profileTable = Get-GerberUserConfigurationPropertyValue -Configuration $AdoConfiguration -PropertyName 'profiles'
    if (($null -ne $profileTable) -and (-not (Test-GerberUserConfigurationRootObject -Configuration $profileTable))) {
        throw [System.IO.InvalidDataException]::new(
            "Gerber user configuration file '$Path' property 'ado.profiles' must be a JSON object."
        )
    }

    return $profileTable
}

function Assert-GerberAdoDefaultProfileReference {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$AdoConfiguration,

        [Parameter(Mandatory)]
        [System.Collections.Generic.Dictionary[string, string]]$ResolvedNameMap,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $defaultProfileName = Get-GerberUserConfigurationPropertyValue -Configuration $AdoConfiguration -PropertyName 'defaultProfile'
    if ($null -eq $defaultProfileName) {
        return
    }

    if ($defaultProfileName -isnot [string]) {
        throw [System.IO.InvalidDataException]::new(
            "Gerber user configuration file '$Path' property 'ado.defaultProfile' must be a string."
        )
    }

    Assert-GerberAdoConnectionProfileName -Name $defaultProfileName -Path $Path -PropertyName 'ado.defaultProfile'
    if (-not $ResolvedNameMap.ContainsKey($defaultProfileName)) {
        throw [System.IO.InvalidDataException]::new(
            "Gerber user configuration file '$Path' property 'ado.defaultProfile' references unknown profile '$defaultProfileName'."
        )
    }
}

function Get-GerberAdoConfigurationEntry {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Configuration
    )

    if ($null -eq $Configuration) {
        return @()
    }

    if ($Configuration -is [System.Collections.IDictionary]) {
        return @(
            foreach ($key in $Configuration.Keys) {
                [pscustomobject]@{
                    Name  = [string]$key
                    Value = $Configuration[$key]
                }
            }
        )
    }

    return @(
        foreach ($property in $Configuration.PSObject.Properties) {
            [pscustomobject]@{
                Name  = [string]$property.Name
                Value = $property.Value
            }
        }
    )
}

function Assert-GerberAdoConnectionProfileName {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Path,

        [string]$PropertyName = 'ado.profiles'
    )

    if ($null -eq $Name) {
        throw [System.IO.InvalidDataException]::new(
            "Gerber user configuration file '$Path' property '$PropertyName' contains a profile with an empty name."
        )
    }

    if ($Name.Length -eq 0) {
        throw [System.IO.InvalidDataException]::new(
            "Gerber user configuration file '$Path' contains an Azure DevOps profile with an empty name."
        )
    }

    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw [System.IO.InvalidDataException]::new(
            "Gerber user configuration file '$Path' contains an Azure DevOps profile with a whitespace-only name."
        )
    }

    if ($Name -ne $Name.Trim()) {
        throw [System.IO.InvalidDataException]::new(
            "Gerber user configuration file '$Path' contains Azure DevOps profile name '$Name' with leading or trailing whitespace."
        )
    }

    if ($Name -match '[\x00-\x1F]') {
        throw [System.IO.InvalidDataException]::new(
            "Gerber user configuration file '$Path' contains Azure DevOps profile name '$Name' with unsupported control characters."
        )
    }
}

function Assert-GerberAdoUniqueConnectionProfileName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [System.Collections.Generic.Dictionary[string, string]]$ResolvedNameMap,

        [Parameter(Mandatory)]
        [string]$Path
    )

    if ($ResolvedNameMap.ContainsKey($Name)) {
        $existingName = $ResolvedNameMap[$Name]
        throw [System.IO.InvalidDataException]::new(
            "Gerber user configuration file '$Path' contains duplicate Azure DevOps profile names '$existingName' and '$Name'. Profile names must be unique ignoring case."
        )
    }

    $ResolvedNameMap[$Name] = $Name
}

function Assert-GerberAdoProfileObject {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$ProfileValue,

        [Parameter(Mandatory)]
        [string]$ProfileName,

        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-GerberUserConfigurationRootObject -Configuration $ProfileValue)) {
        throw [System.IO.InvalidDataException]::new(
            "Gerber user configuration file '$Path' profile '$ProfileName' must be a JSON object."
        )
    }
}

function Test-GerberAdoProfileDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$ProfileValue,

        [Parameter(Mandatory)]
        [string]$ProfileName,

        [Parameter(Mandatory)]
        [string]$Path
    )

    Assert-GerberAdoProfileWithoutCredentialData `
        -ProfileValue $ProfileValue `
        -ProfileName $ProfileName `
        -Path $Path

    $parserArguments = Get-GerberAdoProfileParserArgumentMap `
        -ProfileValue $ProfileValue `
        -ProfileName $ProfileName `
        -Path $Path

    try {
        $null = Resolve-GerberAdoProjectUrl @parserArguments
    } catch {
        throw [System.IO.InvalidDataException]::new(
            "Gerber user configuration file '$Path' has invalid Azure DevOps profile '$ProfileName'. $($_.Exception.Message)",
            $_.Exception
        )
    }
}

function Get-GerberAdoProfileParserArgumentMap {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$ProfileValue,

        [Parameter(Mandatory)]
        [string]$ProfileName,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $projectUrlOption = Get-GerberAdoProfileTextOption `
        -ProfileValue $ProfileValue `
        -ProfileName $ProfileName `
        -Path $Path `
        -PropertyName 'projectUrl'
    if (-not $projectUrlOption.HasValue) {
        throw [System.IO.InvalidDataException]::new(
            "Gerber user configuration file '$Path' profile '$ProfileName' must define string property 'projectUrl'."
        )
    }

    $parserArguments = @{
        Url = $projectUrlOption.Value
    }
    $deploymentTypeOption = Get-GerberAdoProfileTextOption `
        -ProfileValue $ProfileValue `
        -ProfileName $ProfileName `
        -Path $Path `
        -PropertyName 'deploymentType'
    if ($deploymentTypeOption.HasValue) {
        $parserArguments.DeploymentType = $deploymentTypeOption.Value
    }

    $serverUrlOption = Get-GerberAdoProfileTextOption `
        -ProfileValue $ProfileValue `
        -ProfileName $ProfileName `
        -Path $Path `
        -PropertyName 'serverUrl'
    if ($serverUrlOption.HasValue) {
        $parserArguments.ServerUri = ConvertTo-GerberAdoProfileServerUri `
            -ServerUrl $serverUrlOption.Value `
            -ProfileName $ProfileName `
            -Path $Path
    }

    return $parserArguments
}

function Get-GerberAdoProfileTextOption {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$ProfileValue,

        [Parameter(Mandatory)]
        [string]$ProfileName,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    $value = Get-GerberUserConfigurationPropertyValue -Configuration $ProfileValue -PropertyName $PropertyName
    if ($null -eq $value) {
        return [pscustomobject]@{
            HasValue = $false
            Value    = ''
        }
    }

    if ($value -isnot [string]) {
        throw [System.IO.InvalidDataException]::new(
            "Gerber user configuration file '$Path' profile '$ProfileName' property '$PropertyName' must be a string."
        )
    }

    return [pscustomobject]@{
        HasValue = $true
        Value    = $value.Trim()
    }
}

function Assert-GerberAdoProfileWithoutCredentialData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$ProfileValue,

        [Parameter(Mandatory)]
        [string]$ProfileName,

        [Parameter(Mandatory)]
        [string]$Path
    )

    foreach ($propertyName in @('pat', 'password', 'token', 'authorization', 'clientSecret')) {
        if (Test-GerberAdoConfigurationPropertyPresent -Configuration $ProfileValue -PropertyName $propertyName) {
            throw [System.IO.InvalidDataException]::new(
                "Gerber user configuration file '$Path' profile '$ProfileName' must not contain credential field '$propertyName'."
            )
        }
    }
}

function Test-GerberAdoConfigurationPropertyPresent {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Configuration,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    return @(Get-GerberAdoConfigurationEntry -Configuration $Configuration | Where-Object {
            [string]::Equals([string]$_.Name, $PropertyName, [System.StringComparison]::OrdinalIgnoreCase)
        }).Count -gt 0
}

function ConvertTo-GerberAdoProfileServerUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ServerUrl,

        [Parameter(Mandatory)]
        [string]$ProfileName,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $trimmedServerUrl = $ServerUrl.Trim()
    $resolvedUri = $null
    if (-not [System.Uri]::TryCreate($trimmedServerUrl, [System.UriKind]::Absolute, [ref]$resolvedUri)) {
        throw [System.IO.InvalidDataException]::new(
            "Gerber user configuration file '$Path' profile '$ProfileName' property 'serverUrl' must be an absolute URI."
        )
    }

    return $resolvedUri
}
