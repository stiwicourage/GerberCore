function Invoke-GerberPluginsListCommand {
    [CmdletBinding()]
    param(
        [pscustomobject]$Command = [pscustomobject]@{
            Arguments = @()
        }
    )

    Assert-GerberPluginsListCommandInput -Command $Command

    $pluginInventory = @(Get-GerberPluginInventory)
    if ($pluginInventory.Count -eq 0) {
        Show-GerberTextBlock -Title '/plugins list' -Text (Get-GerberPluginListText -PluginInventory $pluginInventory)
        Wait-GerberContinue
        return
    }

    Show-GerberPluginListSelectionView -PluginInventory $pluginInventory
}

function Assert-GerberPluginsListCommandInput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Command
    )

    $argumentProperty = $Command.PSObject.Properties['Arguments']
    $argumentList = @(
        if ($null -eq $argumentProperty -or $null -eq $argumentProperty.Value) {
            @()
        } else {
            @($argumentProperty.Value)
        }
    )

    if ($argumentList.Count -eq 0) {
        return
    }

    throw [System.ArgumentException]::new(
        "The '/plugins list' command does not accept extra arguments."
    )
}

function Get-GerberPluginListText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$PluginInventory
    )

    if ($PluginInventory.Count -eq 0) {
        return 'No plugins are currently discovered or persisted in Gerber user configuration.'
    }

    $tableRowList = @(
        foreach ($plugin in $PluginInventory) {
            [pscustomobject][ordered]@{
                Name       = $plugin.DisplayName
                Version    = $plugin.Version
                Guid       = $plugin.Guid
                Approval   = $plugin.ApprovalStatus
                Associated = Get-GerberPluginAssociationText -IsAssociated $plugin.IsAssociated
                State      = $plugin.State
                Loaded     = Get-GerberPluginLoadedText -Loaded $plugin.Loaded
            }
        }
    )

    return Format-GerberPluginTable `
        -ColumnList @(
            @{ Header = 'Name'; PropertyName = 'Name' }
            @{ Header = 'Version'; PropertyName = 'Version' }
            @{ Header = 'GUID'; PropertyName = 'Guid' }
            @{ Header = 'Approval'; PropertyName = 'Approval' }
            @{ Header = 'Associated'; PropertyName = 'Associated' }
            @{ Header = 'State'; PropertyName = 'State' }
            @{ Header = 'Loaded'; PropertyName = 'Loaded' }
        ) `
        -RowList $tableRowList
}

function Show-GerberPluginListSelectionView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$PluginInventory
    )

    $state = Initialize-GerberPluginListSelectionState -PluginInventory $PluginInventory
    while ($true) {
        try {
            Show-GerberPluginListSelectionScreen -State $state
            $key = Read-GerberMenuConsoleKey
        } catch {
            if (Test-GerberMenuEscapeException -Exception $_.Exception) {
                return
            }

            throw
        }

        if (Test-GerberPromptEscapeRequested -Key $key) {
            return
        }

        if ($key.Key -eq [System.ConsoleKey]::Enter) {
            $plugin = $PluginInventory[$state.FocusedIndex]
            Show-GerberPluginInfoView -Plugin $plugin -ReturnToSelectionOnEscape
            $state.RenderTop = $null
            $state.RenderedLineCount = 0
            $state.ScreenIsInitialized = $false
            continue
        }

        if (Move-GerberNumberedMenuFocusIfRequested -Prompt 'Select plugin (Esc to go back)' -State $state -Key $key) {
            continue
        }
    }
}

function Initialize-GerberPluginListSelectionState {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$PluginInventory
    )

    return @{
        FocusedIndex        = 0
        MenuItemList        = @($PluginInventory)
        RenderTop           = $null
        RenderedLineCount   = 0
        ScreenIsInitialized = $false
    }
}

function Show-GerberPluginListSelectionScreen {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    if (-not $State.ScreenIsInitialized) {
        Show-GerberNumberedMenuPromptScreen -ScreenTitle '/plugins list' -ScreenText ''
        $State.ScreenIsInitialized = $true
    }

    $lineList = Get-GerberPluginListSelectionLineList -State $State
    $null = Show-GerberRenderRegion -State $State -LineList $lineList
}

function Get-GerberPluginListSelectionLineList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    $pluginInventory = @($State.MenuItemList)
    $tableLineList = @((Get-GerberPluginListText -PluginInventory $pluginInventory) -split [Environment]::NewLine)
    $lineList = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($line in @(Get-GerberPluginListDecoratedLineList -TableLineList $tableLineList -FocusedIndex $State.FocusedIndex -PluginCount $pluginInventory.Count)) {
        $lineList.Add($line)
    }

    $lineList.Add((ConvertTo-GerberPromptRenderLine -Text ''))
    $lineList.Add((ConvertTo-GerberPromptRenderLine -Text 'Select plugin (Esc to go back):'))
    return @($lineList)
}

function Get-GerberPluginListDecoratedLineList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$TableLineList,

        [Parameter(Mandatory)]
        [int]$FocusedIndex,

        [Parameter(Mandatory)]
        [int]$PluginCount
    )

    return @(
        for ($index = 0; $index -lt $TableLineList.Count; $index++) {
            $rowIndex = $index - 2
            $isPluginRow = ($rowIndex -ge 0) -and ($rowIndex -lt $PluginCount)
            if (-not $isPluginRow) {
                ConvertTo-GerberPromptRenderLine -Text ("  {0}" -f $TableLineList[$index])
                continue
            }

            $isFocused = $rowIndex -eq $FocusedIndex
            $focusMarker = if ($isFocused) { [string][char]0x276F } else { ' ' }
            ConvertTo-GerberPromptRenderLine `
                -Text ("{0} {1}" -f $focusMarker, $TableLineList[$index]) `
                -IsSelected $isFocused
        }
    )
}

function Get-GerberPluginAssociationText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [bool]$IsAssociated
    )

    if ($IsAssociated) {
        return 'Yes'
    }

    return 'No'
}
