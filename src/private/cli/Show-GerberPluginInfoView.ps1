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
