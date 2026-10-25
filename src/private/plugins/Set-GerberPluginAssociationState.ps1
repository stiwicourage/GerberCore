function Set-GerberPluginAssociationState {
    [OutputType([bool])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [AllowNull()]
        [hashtable]$Configuration,

        [Parameter(Mandatory)]
        [string]$Guid,

        [Parameter(Mandatory)]
        [bool]$Enabled,

        [hashtable]$DisplayMetadata
    )

    if ($null -eq $Configuration) {
        $Configuration = Get-GerberUserConfiguration
    }

    $normalizedGuid = ConvertTo-GerberAssociatedPluginStateGuid -Value $Guid
    $pluginConfiguration = Get-GerberAssociationPluginConfiguration -Configuration $Configuration
    $associatedPluginTable = Get-GerberAssociatedPluginTable -PluginConfiguration $pluginConfiguration
    $associationRecord = Get-GerberUserConfigurationPropertyValue `
        -Configuration $associatedPluginTable `
        -PropertyName $normalizedGuid
    if ((Test-GerberPluginAssociationStateUnchanged -AssociationRecord $associationRecord -Enabled $Enabled) -and $null -eq $DisplayMetadata) {
        return $false
    }

    if (-not $PSCmdlet.ShouldProcess($normalizedGuid, 'Set Gerber plugin association state')) {
        return $false
    }

    $associatedPluginTable[$normalizedGuid] = ConvertTo-GerberAssociatedPluginStateRecord `
        -AssociationRecord $associationRecord `
        -Enabled $Enabled
    if ($null -ne $DisplayMetadata) {
        $associatedPluginTable[$normalizedGuid]['name'] = [string]$DisplayMetadata.name
        $associatedPluginTable[$normalizedGuid]['version'] = [string]$DisplayMetadata.version
    }
    Save-GerberUserConfiguration -Configuration $Configuration
    return $true
}

function ConvertTo-GerberAssociatedPluginStateGuid {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value
    )

    $parsedGuid = [guid]::Empty
    if (($Value -isnot [string]) -or (-not [guid]::TryParse($Value, [ref]$parsedGuid))) {
        throw [System.ArgumentException]::new("Gerber plugin association state received an invalid GUID '$Value'.")
    }

    return $parsedGuid.ToString('D').ToLowerInvariant()
}

function Get-GerberAssociationPluginConfiguration {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration
    )

    $pluginConfiguration = Get-GerberUserConfigurationPropertyValue `
        -Configuration $Configuration `
        -PropertyName 'plugins'
    if ($null -ne $pluginConfiguration) {
        return $pluginConfiguration
    }

    $pluginConfiguration = @{}
    $Configuration['plugins'] = $pluginConfiguration
    return $pluginConfiguration
}

function Get-GerberAssociatedPluginTable {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$PluginConfiguration
    )

    $associatedPluginTable = Get-GerberUserConfigurationPropertyValue `
        -Configuration $PluginConfiguration `
        -PropertyName 'associated'
    if ($null -ne $associatedPluginTable) {
        return $associatedPluginTable
    }

    $associatedPluginTable = @{}
    $PluginConfiguration['associated'] = $associatedPluginTable
    return $associatedPluginTable
}

function Test-GerberPluginAssociationStateUnchanged {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$AssociationRecord,

        [Parameter(Mandatory)]
        [bool]$Enabled
    )

    if ($null -eq $AssociationRecord) {
        return $false
    }

    $currentEnabled = Get-GerberUserConfigurationPropertyValue `
        -Configuration $AssociationRecord `
        -PropertyName 'enabled'
    return ($currentEnabled -is [bool]) -and ($currentEnabled -eq $Enabled)
}

function ConvertTo-GerberAssociatedPluginStateRecord {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$AssociationRecord,

        [Parameter(Mandatory)]
        [bool]$Enabled
    )

    $updatedRecord = @{}
    foreach ($entry in @(Get-GerberAssociationRecordEntryList -AssociationRecord $AssociationRecord)) {
        $updatedRecord[$entry.Name] = $entry.Value
    }

    $updatedRecord['enabled'] = $Enabled
    return $updatedRecord
}

function Get-GerberAssociationRecordEntryList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$AssociationRecord
    )

    if ($null -eq $AssociationRecord) {
        return @()
    }

    if ($AssociationRecord -is [System.Collections.IDictionary]) {
        return @(
            foreach ($key in $AssociationRecord.Keys) {
                [pscustomobject]@{
                    Name  = [string]$key
                    Value = $AssociationRecord[$key]
                }
            }
        )
    }

    return @(
        foreach ($property in $AssociationRecord.PSObject.Properties) {
            [pscustomobject]@{
                Name  = $property.Name
                Value = $property.Value
            }
        }
    )
}
