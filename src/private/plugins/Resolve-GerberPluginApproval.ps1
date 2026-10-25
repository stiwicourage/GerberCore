function Resolve-GerberPluginApproval {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PluginModule,

        [switch]$ExplicitApproval,

        [hashtable]$DisplayMetadata
    )

    $configuration = Get-GerberUserConfiguration
    if ($ExplicitApproval) {
        return (Save-GerberApprovedPluginDecision -Configuration $configuration -PluginModule $PluginModule -DisplayMetadata $DisplayMetadata)
    }

    $knownDecision = Resolve-GerberKnownPluginApprovalDecision `
        -Configuration $configuration `
        -PluginModule $PluginModule
    if ($knownDecision.IsResolved) {
        return $knownDecision.IsApproved
    }

    Write-GerberUnknownPluginApprovalTrace -PluginModule $PluginModule
    if (-not (Test-GerberInteractivePromptAvailable)) {
        return (Complete-GerberUnknownPluginApprovalNoninteractive -PluginModule $PluginModule)
    }

    $approved = Read-GerberPluginApprovalPrompt -PluginModule $PluginModule
    Write-GerberPromptTrace -EventName 'plugin-approval-decision' -Data @{
        Name = $PluginModule.Name
        Approved = $approved
    }
    return (Complete-GerberPluginApprovalDecision `
            -Configuration $configuration `
            -PluginModule $PluginModule `
            -Approved $approved)
}

function Resolve-GerberKnownPluginApprovalDecision {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration,

        [Parameter(Mandatory)]
        [pscustomobject]$PluginModule
    )

    if (Test-GerberPluginGuidDecision -Configuration $Configuration -PropertyName 'approved' -Guid $PluginModule.Guid) {
        Complete-GerberLegacyPluginAssociationBackfill `
            -Configuration $Configuration `
            -PluginModule $PluginModule
        return [hashtable]@{
            IsResolved = $true
            IsApproved = $true
        }
    }

    return [hashtable]@{
        IsResolved = (Test-GerberPluginGuidDecision -Configuration $Configuration -PropertyName 'declined' -Guid $PluginModule.Guid)
        IsApproved = $false
    }
}

function Complete-GerberLegacyPluginAssociationBackfill {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration,

        [Parameter(Mandatory)]
        [pscustomobject]$PluginModule
    )

    $lifecycleState = Get-GerberPluginLifecycleState `
        -Configuration $Configuration `
        -Guid $PluginModule.Guid
    if (-not $lifecycleState.IsAssociated) {
        $null = Set-GerberPluginAssociationState `
            -Configuration $Configuration `
            -Guid $PluginModule.Guid `
            -Enabled $true
    }
}

function Write-GerberUnknownPluginApprovalTrace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PluginModule
    )

    Write-GerberPromptTrace -EventName 'plugin-approval-unknown' -Data @{
        Name = $PluginModule.Name
        Guid = $PluginModule.Guid
    }
}

function Complete-GerberUnknownPluginApprovalNoninteractive {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PluginModule
    )

    Write-GerberPromptTrace -EventName 'plugin-approval-skipped' -Data @{
        Name = $PluginModule.Name
        Reason = 'noninteractive'
    }
    Write-Warning "Skipping unknown Gerber plugin '$($PluginModule.Name)' because approval cannot be requested noninteractively."
    return $false
}

function Complete-GerberPluginApprovalDecision {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration,

        [Parameter(Mandatory)]
        [pscustomobject]$PluginModule,

        [Parameter(Mandatory)]
        [bool]$Approved
    )

    if (-not $Approved) {
        return (Save-GerberDeclinedPluginDecision -Configuration $Configuration -PluginModule $PluginModule)
    }

    return (Save-GerberApprovedPluginDecision -Configuration $Configuration -PluginModule $PluginModule)
}

function Save-GerberDeclinedPluginDecision {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration,

        [Parameter(Mandatory)]
        [pscustomobject]$PluginModule
    )

    $declineAdded = Add-GerberPluginGuidDecision `
        -Configuration $Configuration `
        -PropertyName 'declined' `
        -Guid $PluginModule.Guid
    if ($declineAdded) {
        Save-GerberUserConfiguration -Configuration $Configuration
    }

    return $false
}

function Save-GerberApprovedPluginDecision {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration,

        [Parameter(Mandatory)]
        [pscustomobject]$PluginModule,

        [hashtable]$DisplayMetadata
    )

    $approvalAdded = Add-GerberPluginGuidDecision `
        -Configuration $Configuration `
        -PropertyName 'approved' `
        -Guid $PluginModule.Guid
    $declineRemoved = Remove-GerberPluginGuidDecision `
        -Configuration $Configuration `
        -PropertyName 'declined' `
        -Guid $PluginModule.Guid
    $associationChanged = Set-GerberPluginAssociationState `
        -Configuration $Configuration `
        -Guid $PluginModule.Guid `
        -Enabled $true `
        -DisplayMetadata $DisplayMetadata
    if (Test-GerberPluginDecisionSaveRequired `
            -ApprovalAdded $approvalAdded `
            -DeclineRemoved $declineRemoved `
            -AssociationChanged $associationChanged) {
        Save-GerberUserConfiguration -Configuration $Configuration
    }

    Write-GerberPromptTrace -EventName 'plugin-approval-persisted' -Data @{
        Name = $PluginModule.Name
        Guid = $PluginModule.Guid
    }
    return $true
}

function Test-GerberPluginDecisionSaveRequired {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [bool]$ApprovalAdded,

        [Parameter(Mandatory)]
        [bool]$DeclineRemoved,

        [Parameter(Mandatory)]
        [bool]$AssociationChanged
    )

    return ($ApprovalAdded -or $DeclineRemoved) -and (-not $AssociationChanged)
}

function Test-GerberPluginGuidDecision {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration,

        [Parameter(Mandatory)]
        [string]$PropertyName,

        [Parameter(Mandatory)]
        [string]$Guid
    )

    $pluginConfiguration = Get-GerberUserConfigurationPropertyValue `
        -Configuration $Configuration `
        -PropertyName 'plugins'
    if ($null -eq $pluginConfiguration) {
        return $false
    }
    $guidList = Get-GerberUserConfigurationPropertyValue `
        -Configuration $pluginConfiguration `
        -PropertyName $PropertyName
    return @($guidList) -icontains $Guid
}

function Read-GerberPluginApprovalPrompt {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PluginModule
    )

    $promptOptionSet = Get-GerberConfirmationPromptOptionSet `
        -ActionLabel 'Approve' `
        -CancelLabel 'Decline' `
        -ActionPreviewText 'Approve this plugin GUID and load the plugin.' `
        -CancelPreviewText 'Skip this plugin and continue starting Gerber.' `
        -DefaultOption 'cancel'
    return Read-GerberConfirmationPrompt `
        -ScreenTitle 'Unknown Gerber plugin detected' `
        -ScreenText (Get-GerberPluginApprovalScreenText -PluginModule $PluginModule) `
        -Prompt 'Approve this plugin?' `
        -PromptOptionSet $promptOptionSet
}

function Get-GerberPluginApprovalScreenText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PluginModule
    )

    $publisher = Get-GerberPluginPublisher -PluginModule $PluginModule
    return @(
        "Name:       $($PluginModule.Name)"
        "GUID:       $($PluginModule.Guid)"
        "Version:    $($PluginModule.Version)"
        "Publisher:  $publisher"
        "Location:   $($PluginModule.Path)"
    ) -join [Environment]::NewLine
}

function Get-GerberPluginPublisher {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PluginModule
    )

    if (-not [string]::IsNullOrWhiteSpace($PluginModule.Author)) {
        return $PluginModule.Author
    }
    if (-not [string]::IsNullOrWhiteSpace($PluginModule.CompanyName)) {
        return $PluginModule.CompanyName
    }
    return '[not specified]'
}

function Add-GerberPluginGuidDecision {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration,

        [Parameter(Mandatory)]
        [string]$PropertyName,

        [Parameter(Mandatory)]
        [string]$Guid
    )

    $pluginConfiguration = Get-GerberOrCreatePluginConfiguration -Configuration $Configuration
    $guidList = @(
        Get-GerberUserConfigurationPropertyValue -Configuration $pluginConfiguration -PropertyName $PropertyName
    )
    if ($guidList -icontains $Guid) {
        return $false
    }
    $pluginConfiguration[$PropertyName] = @($guidList + $Guid | Sort-Object -Unique)
    return $true
}

function Remove-GerberPluginGuidDecision {
    [OutputType([bool])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration,

        [Parameter(Mandatory)]
        [string]$PropertyName,

        [Parameter(Mandatory)]
        [string]$Guid
    )

    $pluginConfiguration = Get-GerberUserConfigurationPropertyValue `
        -Configuration $Configuration `
        -PropertyName 'plugins'
    if ($null -eq $pluginConfiguration) {
        return $false
    }

    $guidList = @(
        Get-GerberUserConfigurationPropertyValue -Configuration $pluginConfiguration -PropertyName $PropertyName
    )
    if ($guidList -inotcontains $Guid) {
        return $false
    }

    if (-not $PSCmdlet.ShouldProcess($Guid, "Remove Gerber plugin '$PropertyName' decision")) {
        return $false
    }

    $pluginConfiguration[$PropertyName] = @(
        foreach ($listedGuid in $guidList) {
            if ($listedGuid -ine $Guid) {
                $listedGuid
            }
        }
    )
    return $true
}

function Get-GerberOrCreatePluginConfiguration {
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
