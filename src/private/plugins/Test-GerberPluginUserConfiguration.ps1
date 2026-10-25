function Test-GerberPluginUserConfiguration {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Configuration,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $pluginConfiguration = Get-GerberUserConfigurationPropertyValue `
        -Configuration $Configuration `
        -PropertyName 'plugins'
    if ($null -eq $pluginConfiguration) {
        return $true
    }
    if (-not (Test-GerberUserConfigurationRootObject -Configuration $pluginConfiguration)) {
        throw [System.IO.InvalidDataException]::new(
            "Gerber user configuration file '$Path' property 'plugins' must be a JSON object."
        )
    }

    $approvedGuidList = Get-GerberPluginConfigurationPropertyValue `
        -Configuration $pluginConfiguration `
        -PropertyName 'approved'
    Assert-GerberPluginGuidList `
        -GuidList $approvedGuidList `
        -Path $Path `
        -PropertyPath 'plugins.approved' `
        -DuplicateMessage "Gerber user configuration file '$Path' property 'plugins.approved' contains a duplicate GUID."

    $declinedGuidList = Get-GerberPluginConfigurationPropertyValue `
        -Configuration $pluginConfiguration `
        -PropertyName 'declined'
    Assert-GerberPluginGuidList `
        -GuidList $declinedGuidList `
        -Path $Path `
        -PropertyPath 'plugins.declined' `
        -DuplicateMessage "Gerber user configuration file '$Path' property 'plugins.declined' contains a duplicate GUID."

    $associatedPluginTable = Get-GerberPluginConfigurationPropertyValue `
        -Configuration $pluginConfiguration `
        -PropertyName 'associated'
    Assert-GerberAssociatedPluginStateTable -AssociatedPluginTable $associatedPluginTable -Path $Path
    return $true
}

function Get-GerberPluginConfigurationPropertyValue {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Configuration,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    if ($Configuration -is [System.Collections.IDictionary]) {
        return ,$Configuration[$PropertyName]
    }
    return ,$Configuration.PSObject.Properties[$PropertyName].Value
}

function Assert-GerberPluginGuidList {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$GuidList,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$PropertyPath,

        [Parameter(Mandatory)]
        [string]$DuplicateMessage
    )

    if ($null -eq $GuidList) {
        return
    }
    if (($GuidList -is [string]) -or ($GuidList -is [System.Collections.IDictionary])) {
        throw [System.IO.InvalidDataException]::new(
            "Gerber user configuration file '$Path' property '$PropertyPath' must be a JSON array."
        )
    }

    $normalizedGuidList = @(
        foreach ($listedGuid in @($GuidList)) {
            ConvertTo-GerberPluginConfigurationGuid `
                -Value $listedGuid `
                -Path $Path `
                -PropertyPath $PropertyPath
        }
    )
    if (@($normalizedGuidList | Select-Object -Unique).Count -ne $normalizedGuidList.Count) {
        throw [System.IO.InvalidDataException]::new($DuplicateMessage)
    }
}

function Assert-GerberAssociatedPluginStateTable {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$AssociatedPluginTable,

        [Parameter(Mandatory)]
        [string]$Path
    )

    if ($null -eq $AssociatedPluginTable) {
        return
    }
    if (-not (Test-GerberUserConfigurationRootObject -Configuration $AssociatedPluginTable)) {
        throw [System.IO.InvalidDataException]::new(
            "Gerber user configuration file '$Path' property 'plugins.associated' must be a JSON object."
        )
    }

    foreach ($entry in @(Get-GerberPluginConfigurationEntryList -Configuration $AssociatedPluginTable)) {
        $guid = ConvertTo-GerberPluginConfigurationGuid `
            -Value $entry.Name `
            -Path $Path `
            -PropertyPath 'plugins.associated'
        Assert-GerberAssociatedPluginStateRecord -AssociationRecord $entry.Value -Guid $guid -Path $Path
    }
}

function Get-GerberPluginConfigurationEntryList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Configuration
    )

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
                Name  = $property.Name
                Value = $property.Value
            }
        }
    )
}

function ConvertTo-GerberPluginConfigurationGuid {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$PropertyPath
    )

    $parsedGuid = [guid]::Empty
    if (($Value -isnot [string]) -or (-not [guid]::TryParse($Value, [ref]$parsedGuid))) {
        throw [System.IO.InvalidDataException]::new(
            "Gerber user configuration file '$Path' property '$PropertyPath' must contain only valid GUID values."
        )
    }

    return $parsedGuid.ToString('D').ToLowerInvariant()
}

function Assert-GerberAssociatedPluginStateRecord {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$AssociationRecord,

        [Parameter(Mandatory)]
        [string]$Guid,

        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-GerberUserConfigurationRootObject -Configuration $AssociationRecord)) {
        throw [System.IO.InvalidDataException]::new(
            "Gerber user configuration file '$Path' property 'plugins.associated.$Guid' must be a JSON object."
        )
    }

    $enabled = Get-GerberUserConfigurationPropertyValue `
        -Configuration $AssociationRecord `
        -PropertyName 'enabled'
    if ($enabled -isnot [bool]) {
        throw [System.IO.InvalidDataException]::new(
            "Gerber user configuration file '$Path' property 'plugins.associated.$Guid.enabled' must be a Boolean."
        )
    }
}
