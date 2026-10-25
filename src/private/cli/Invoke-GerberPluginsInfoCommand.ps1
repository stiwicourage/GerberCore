function Invoke-GerberPluginsInfoCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Command
    )

    $pluginInventory = @(Get-GerberPluginInventory)
    $pluginLookup = Get-GerberPluginInfoLookupText -Command $Command
    $plugin = Get-GerberSelectedPluginInventoryEntry -PluginInventory $pluginInventory -LookupText $pluginLookup

    Show-GerberPluginInfoView -Plugin $plugin
}

function Get-GerberPluginInfoLookupText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Command
    )

    $argumentList = @($Command.Arguments)
    if ($argumentList.Count -eq 0) {
        return Read-GerberPluginInfoLookupText
    }

    if ($argumentList.Count -gt 1) {
        throw [System.ArgumentException]::new(
            'Specify exactly one plugin GUID or unique module name.'
        )
    }

    return [string]$argumentList[0]
}

function Read-GerberPluginInfoLookupText {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    Start-GerberScreen -Name '/plugins info'
    Write-GerberScreenLine -Text '/plugins info'
    Write-GerberScreenLine

    $lookupText = Read-GerberCommand `
        -Prompt 'Plugin GUID or unique module name' `
        -SuggestionMode 'None' `
        -TrimResult $true
    if ([string]::IsNullOrWhiteSpace($lookupText)) {
        throw [System.ArgumentException]::new(
            'Specify exactly one plugin GUID or unique module name.'
        )
    }

    return $lookupText
}
function Get-GerberSelectedPluginInventoryEntry {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$PluginInventory,

        [Parameter(Mandatory)]
        [string]$LookupText
    )

    $normalizedLookup = $LookupText.Trim()
    if ([string]::IsNullOrWhiteSpace($normalizedLookup)) {
        throw [System.ArgumentException]::new(
            'Specify exactly one plugin GUID or unique module name.'
        )
    }

    $resolvedGuid = Resolve-GerberPluginLookupGuid -LookupText $normalizedLookup
    if ($null -ne $resolvedGuid) {
        return Find-GerberPluginInventoryEntryByGuid -PluginInventory $PluginInventory -Guid $resolvedGuid
    }

    $matchingPluginList = @(
        foreach ($plugin in $PluginInventory) {
            if (-not [string]::IsNullOrWhiteSpace($plugin.Name) -and ($plugin.Name -ieq $normalizedLookup)) {
                $plugin
            }
        }
    )
    if ($matchingPluginList.Count -eq 0) {
        throw [System.ArgumentException]::new(
            "Gerber does not know a plugin named '$normalizedLookup'."
        )
    }

    if ($matchingPluginList.Count -gt 1) {
        $guidList = @($matchingPluginList.Guid | Sort-Object) -join ', '
        throw [System.ArgumentException]::new(
            "Gerber found multiple discovered plugins named '$normalizedLookup'. Use one of these GUIDs instead: $guidList."
        )
    }

    return $matchingPluginList[0]
}

function Resolve-GerberPluginLookupGuid {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LookupText
    )

    if (-not (Test-GerberGuidLikePluginLookup -LookupText $LookupText)) {
        return $null
    }

    $parsedGuid = [guid]::Empty
    if (-not [guid]::TryParse($LookupText, [ref]$parsedGuid)) {
        throw [System.ArgumentException]::new(
            "Plugin identifier '$LookupText' is not a valid GUID. Use a manifest GUID or a unique module name."
        )
    }

    return $parsedGuid.ToString('D').ToLowerInvariant()
}

function Test-GerberGuidLikePluginLookup {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LookupText
    )

    return $LookupText -match '^[\{\(]?[0-9A-Fa-f]{8}-'
}

function Find-GerberPluginInventoryEntryByGuid {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$PluginInventory,

        [Parameter(Mandatory)]
        [string]$Guid
    )

    foreach ($plugin in $PluginInventory) {
        if ([string]$plugin.Guid -eq $Guid) {
            return $plugin
        }
    }

    throw [System.ArgumentException]::new(
        "Gerber does not know a plugin with GUID '$Guid'."
    )
}

function Get-GerberPluginInfoText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Plugin
    )

    $sectionList = @(
        "Plugin: $($Plugin.DisplayName)"
        ''
        "GUID:         $($Plugin.Guid)"
        "Module name:  $(Get-GerberPluginInfoValue -Value $Plugin.Name)"
        "Version:      $(Get-GerberPluginInfoValue -Value $Plugin.Version)"
        "Description:  $(Get-GerberPluginInfoValue -Value $Plugin.Description)"
        "Author:       $(Get-GerberPluginInfoValue -Value $Plugin.Author)"
        "Company:      $(Get-GerberPluginInfoValue -Value $Plugin.CompanyName)"
        "Location:     $(Get-GerberPluginInfoValue -Value $Plugin.ModulePath)"
        "Approval:     $($Plugin.ApprovalStatus)"
        "Associated:   $(Get-GerberPluginAssociationText -IsAssociated $Plugin.IsAssociated)"
        "Enabled:      $(Get-GerberPluginEnabledText -Plugin $Plugin)"
        "Loaded:       $(Get-GerberPluginLoadedText -Loaded $Plugin.Loaded)"
        "State:        $($Plugin.State)"
        "Namespaces:   $(Get-GerberPluginInfoListText -ValueList $Plugin.RegisteredNamespaceList -Prefix '/')"
        "Commands:     $(Get-GerberPluginInfoListText -ValueList $Plugin.RegisteredCommandList -Prefix '/')"
    )

    if ($Plugin.ApprovalStatus -eq 'Declined') {
        $sectionList += @(
            ''
            'This plugin was previously declined and will not be loaded or prompt for approval automatically.'
        )
    }

    return ($sectionList -join [Environment]::NewLine)
}

function Show-GerberPluginInfoView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Plugin,

        [switch]$ReturnToSelectionOnEscape
    )

    Show-GerberTextBlock -Title '/plugins info' -Text (Get-GerberPluginInfoText -Plugin $Plugin)
    try {
        Wait-GerberContinue
    } catch {
        if ($ReturnToSelectionOnEscape -and (Test-GerberMenuEscapeException -Exception $_.Exception)) {
            return
        }

        throw
    }
}

function Get-GerberPluginEnabledText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Plugin
    )

    if (-not $Plugin.IsAssociated) {
        return [string][char]0x2014
    }

    if ($Plugin.IsEnabled) {
        return 'Yes'
    }

    return 'No'
}

function Get-GerberPluginInfoValue {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return [string][char]0x2014
    }

    return $Value
}

function Get-GerberPluginInfoListText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [string[]]$ValueList = @(),

        [string]$Prefix = ''
    )

    if (@($ValueList).Count -eq 0) {
        return [string][char]0x2014
    }

    return @(
        foreach ($value in $ValueList) {
            if ([string]::IsNullOrWhiteSpace($value)) {
                continue
            }

            "$Prefix$value"
        }
    ) -join ', '
}
