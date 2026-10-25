function Get-GerberPluginLifecycleState {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [hashtable]$Configuration,

        [Parameter(Mandatory)]
        [string]$Guid
    )

    if ($null -eq $Configuration) {
        $Configuration = Get-GerberUserConfiguration
    }

    $normalizedGuid = ConvertTo-GerberPluginLifecycleGuid -Value $Guid
    $pluginConfiguration = Get-GerberUserConfigurationPropertyValue `
        -Configuration $Configuration `
        -PropertyName 'plugins'
    if ($null -eq $pluginConfiguration) {
        return (ConvertTo-GerberPluginLifecycleStateRecord -Guid $normalizedGuid)
    }

    $associatedPluginTable = Get-GerberUserConfigurationPropertyValue `
        -Configuration $pluginConfiguration `
        -PropertyName 'associated'
    if ($null -eq $associatedPluginTable) {
        return (ConvertTo-GerberPluginLifecycleStateRecord -Guid $normalizedGuid)
    }

    $associationRecord = Get-GerberUserConfigurationPropertyValue `
        -Configuration $associatedPluginTable `
        -PropertyName $normalizedGuid
    if ($null -eq $associationRecord) {
        return (ConvertTo-GerberPluginLifecycleStateRecord -Guid $normalizedGuid)
    }

    $enabled = Get-GerberUserConfigurationPropertyValue `
        -Configuration $associationRecord `
        -PropertyName 'enabled'
    return (ConvertTo-GerberPluginLifecycleStateRecord -Guid $normalizedGuid -IsAssociated $true -IsEnabled ([bool]$enabled))
}

function ConvertTo-GerberPluginLifecycleGuid {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value
    )

    $parsedGuid = [guid]::Empty
    if (($Value -isnot [string]) -or (-not [guid]::TryParse($Value, [ref]$parsedGuid))) {
        throw [System.ArgumentException]::new("Gerber plugin lifecycle state received an invalid GUID '$Value'.")
    }

    return $parsedGuid.ToString('D').ToLowerInvariant()
}

function ConvertTo-GerberPluginLifecycleStateRecord {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Guid,

        [bool]$IsAssociated = $false,

        [bool]$IsEnabled = $true
    )

    return [pscustomobject][ordered]@{
        Guid         = $Guid
        IsAssociated = $IsAssociated
        IsEnabled    = $IsEnabled
        ShouldLoad   = (-not $IsAssociated) -or $IsEnabled
    }
}
