function Read-GerberCheckboxMenuPrompt {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PromptRequest
    )
    $null = $PSCmdlet.ShouldProcess('Read-GerberCheckboxMenuPrompt', 'Invoke')

    $state = Initialize-GerberCheckboxMenuPromptState -ItemList @($PromptRequest.ItemList)
    Write-GerberPromptTrace -EventName 'checkbox-open' -Data @{
        Prompt        = $PromptRequest.Prompt
        ItemCount     = $state.ItemStateList.Count
        SelectedCount = Get-GerberCheckboxMenuSelectedCount -State $state
    }
    while ($true) {
        Show-GerberCheckboxMenuPromptScreen `
            -PromptRequest $PromptRequest `
            -State $state
        $key = Read-GerberMenuConsoleKey
        Write-GerberPromptTrace -EventName 'checkbox-key-read' -Data @{
            Prompt        = $PromptRequest.Prompt
            Key           = $key.Key.ToString()
            KeyChar       = [int][char]$key.KeyChar
            FocusedIndex  = $state.FocusedIndex
            SelectedCount = Get-GerberCheckboxMenuSelectedCount -State $state
        }

        if (Test-GerberPromptEscapeRequested -Key $key) {
            Write-GerberPromptTrace -EventName 'checkbox-cancel' -Data @{
                Prompt        = $PromptRequest.Prompt
                FocusedIndex  = $state.FocusedIndex
                SelectedCount = Get-GerberCheckboxMenuSelectedCount -State $state
            }
            throw (Get-GerberMenuEscapeException)
        }

        $keyResult = Invoke-GerberCheckboxMenuPromptKey `
            -PromptRequest $PromptRequest `
            -State $state `
            -Key $key
        if ($keyResult.ShouldSubmit) {
            return Get-GerberCheckboxMenuPromptResult -State $state
        }
    }
}

function Initialize-GerberCheckboxMenuPromptState {
    [OutputType([hashtable])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$ItemList
    )
    $null = $PSCmdlet.ShouldProcess('Initialize-GerberCheckboxMenuPromptState', 'Invoke')

    return @{
        FocusedIndex        = 0
        ItemStateList       = @(ConvertTo-GerberCheckboxMenuItemStateList -ItemList $ItemList)
        RenderTop           = $null
        RenderedLineCount   = 0
        ScreenIsInitialized = $false
    }
}

function ConvertTo-GerberCheckboxMenuItemStateList {
    [OutputType([object[]])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$ItemList
    )
    $null = $PSCmdlet.ShouldProcess('ConvertTo-GerberCheckboxMenuItemStateList', 'Invoke')

    return @(
        foreach ($item in $ItemList) {
            [pscustomobject]@{
                Label       = [string]$item.Label
                Value       = $item.Value
                Description = if ($item.PSObject.Properties.Name -contains 'Description') { [string]$item.Description } else { '' }
                IsSelected  = if ($item.PSObject.Properties.Name -contains 'IsSelected') { [bool]$item.IsSelected } else { $true }
                OriginalItem = $item
            }
        }
    )
}

function Show-GerberCheckboxMenuPromptScreen {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PromptRequest,

        [Parameter(Mandatory)]
        [hashtable]$State
    )
    $null = $PSCmdlet.ShouldProcess('Show-GerberCheckboxMenuPromptScreen', 'Invoke')

    if (-not $State.ScreenIsInitialized) {
        Show-GerberNumberedMenuPromptScreen `
            -ScreenTitle ([string]$PromptRequest.ScreenTitle) `
            -ScreenText ([string]$PromptRequest.ScreenText)
        $State.ScreenIsInitialized = $true
    }

    $lineList = @(Get-GerberCheckboxMenuPromptLineList -PromptRequest $PromptRequest -State $State)
    $renderResult = Show-GerberRenderRegion -State $State -LineList $lineList
    Write-GerberPromptTrace -EventName 'checkbox-render' -Data @{
        Prompt                 = $PromptRequest.Prompt
        FocusedIndex           = $State.FocusedIndex
        RenderTop              = $renderResult.RenderTop
        PreviousRenderedLines  = $renderResult.PreviousRenderedLines
        NewRenderedLines       = $renderResult.NewRenderedLines
        ItemCount              = $State.ItemStateList.Count
        SelectedCount          = Get-GerberCheckboxMenuSelectedCount -State $State
        Width                  = Get-GerberPromptTraceWidthOrNull
        UsedFallback           = $renderResult.UsedFallback
    }
}

function Get-GerberCheckboxMenuPromptLineList {
    [OutputType([object[]])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PromptRequest,

        [Parameter(Mandatory)]
        [hashtable]$State
    )
    $null = $PSCmdlet.ShouldProcess('Get-GerberCheckboxMenuPromptLineList', 'Invoke')

    $lineList = [System.Collections.Generic.List[pscustomobject]]::new()
    if ($State.ItemStateList.Count -eq 0) {
        $lineList.Add((ConvertTo-GerberPromptRenderLine -Text '- None'))
    } else {
        for ($index = 0; $index -lt $State.ItemStateList.Count; $index++) {
            foreach ($line in @(Get-GerberCheckboxMenuItemLineList `
                        -ItemState $State.ItemStateList[$index] `
                        -Focused ($index -eq $State.FocusedIndex))) {
                $lineList.Add($line)
            }
        }
    }

    $lineList.Add((ConvertTo-GerberPromptRenderLine -Text ''))
    $lineList.Add((ConvertTo-GerberPromptRenderLine -Text "$($PromptRequest.Prompt)  Up/Down move | Space toggle | Enter continue | Esc back"))
    return @($lineList)
}

function Get-GerberCheckboxMenuItemLineList {
    [OutputType([object[]])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$ItemState,

        [bool]$Focused
    )
    $null = $PSCmdlet.ShouldProcess('Get-GerberCheckboxMenuItemLineList', 'Invoke')

    $focusMarker = if ($Focused) { [string][char]0x276F } else { ' ' }
    $selectionMarker = if ($ItemState.IsSelected) { '[{0}]' -f ([string][char]0x2714) } else { '[ ]' }
    $lineList = [System.Collections.Generic.List[pscustomobject]]::new()
    $lineList.Add((ConvertTo-GerberPromptRenderLine -Text "$focusMarker $selectionMarker $($ItemState.Label)" -IsSelected $Focused))
    if (-not [string]::IsNullOrWhiteSpace($ItemState.Description)) {
        $lineList.Add((ConvertTo-GerberPromptRenderLine -Text "    $($ItemState.Description)"))
    }

    return @($lineList)
}

function Invoke-GerberCheckboxMenuPromptKey {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PromptRequest,

        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [System.ConsoleKeyInfo]$Key
    )
    $null = $PSCmdlet.ShouldProcess('Invoke-GerberCheckboxMenuPromptKey', 'Invoke')

    if (Test-GerberTabKey -Key $Key) {
        Write-GerberCheckboxMenuIgnoredKeyTrace -Prompt $PromptRequest.Prompt -Key 'Tab'
        return [pscustomobject]@{ ShouldSubmit = $false }
    }

    if (Test-GerberCheckboxMenuFocusKey `
            -Prompt $PromptRequest.Prompt `
            -State $State `
            -Key $Key) {
        return [pscustomobject]@{ ShouldSubmit = $false }
    }

    if (Test-GerberCheckboxMenuToggleKey `
            -Prompt $PromptRequest.Prompt `
            -State $State `
            -Key $Key) {
        return [pscustomobject]@{ ShouldSubmit = $false }
    }

    if (Test-GerberCheckboxMenuSubmitKey `
            -PromptRequest $PromptRequest `
            -State $State `
            -Key $Key) {
        return [pscustomobject]@{ ShouldSubmit = $true }
    }

    Write-GerberCheckboxMenuIgnoredKeyTrace -Prompt $PromptRequest.Prompt -Key $Key.Key.ToString()
    return [pscustomobject]@{ ShouldSubmit = $false }
}

function Test-GerberCheckboxMenuFocusKey {
    [OutputType([bool])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [System.ConsoleKeyInfo]$Key
    )
    $null = $PSCmdlet.ShouldProcess('Test-GerberCheckboxMenuFocusKey', 'Invoke')

    $direction = Get-GerberCheckboxMenuFocusDirection -Key $Key
    if ([string]::IsNullOrWhiteSpace($direction)) {
        return $false
    }

    Move-GerberCheckboxMenuFocus -State $State -Direction $direction
    Write-GerberPromptTrace -EventName 'checkbox-focus' -Data @{
        Prompt       = $Prompt
        Direction    = $direction
        FocusedIndex = $State.FocusedIndex
    }
    return $true
}

function Get-GerberCheckboxMenuFocusDirection {
    [OutputType([string])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [System.ConsoleKeyInfo]$Key
    )
    $null = $PSCmdlet.ShouldProcess('Get-GerberCheckboxMenuFocusDirection', 'Invoke')

    switch ($Key.Key) {
        ([System.ConsoleKey]::UpArrow) { return 'Previous' }
        ([System.ConsoleKey]::DownArrow) { return 'Next' }
        ([System.ConsoleKey]::Home) { return 'First' }
        ([System.ConsoleKey]::End) { return 'Last' }
        default { return '' }
    }
}

function Test-GerberCheckboxMenuToggleKey {
    [OutputType([bool])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [System.ConsoleKeyInfo]$Key
    )
    $null = $PSCmdlet.ShouldProcess('Test-GerberCheckboxMenuToggleKey', 'Invoke')

    if ($Key.Key -ne [System.ConsoleKey]::Spacebar) {
        return $false
    }

    Select-GerberCheckboxMenuFocusedItemState -State $State
    Write-GerberPromptTrace -EventName 'checkbox-toggle' -Data @{
        Prompt        = $Prompt
        FocusedIndex  = $State.FocusedIndex
        SelectedCount = Get-GerberCheckboxMenuSelectedCount -State $State
    }
    return $true
}

function Test-GerberCheckboxMenuSubmitKey {
    [OutputType([bool])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PromptRequest,

        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [System.ConsoleKeyInfo]$Key
    )
    $null = $PSCmdlet.ShouldProcess('Test-GerberCheckboxMenuSubmitKey', 'Invoke')

    if ($Key.Key -ne [System.ConsoleKey]::Enter) {
        return $false
    }

    if ((Get-GerberCheckboxMenuSelectedCount -State $State) -lt 1 -and -not (Test-GerberCheckboxMenuAllowsEmptySelection -PromptRequest $PromptRequest)) {
        Write-GerberPromptTrace -EventName 'checkbox-submit-blocked' -Data @{
            Prompt = $PromptRequest.Prompt
            Reason = 'NoSelection'
        }
        Reset-GerberCheckboxMenuPromptRenderState -State $State
        Show-GerberCheckboxMenuRecoverableError `
            -ScreenTitle ([string]$PromptRequest.ScreenTitle) `
            -Message ([string]$PromptRequest.EmptySelectionMessage)
        return $false
    }

    Write-GerberPromptTrace -EventName 'checkbox-submit' -Data @{
        Prompt        = $PromptRequest.Prompt
        FocusedIndex  = $State.FocusedIndex
        SelectedCount = Get-GerberCheckboxMenuSelectedCount -State $State
    }
    return $true
}

function Test-GerberCheckboxMenuAllowsEmptySelection {
    [OutputType([bool])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PromptRequest
    )
    $null = $PSCmdlet.ShouldProcess('Test-GerberCheckboxMenuAllowsEmptySelection', 'Invoke')

    if ($PromptRequest.PSObject.Properties.Name -notcontains 'AllowEmptySelection') {
        return $false
    }

    return [bool]$PromptRequest.AllowEmptySelection
}

function Write-GerberCheckboxMenuIgnoredKeyTrace {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter(Mandatory)]
        [string]$Key
    )
    $null = $PSCmdlet.ShouldProcess('Write-GerberCheckboxMenuIgnoredKeyTrace', 'Invoke')

    Write-GerberPromptTrace -EventName 'checkbox-key-ignored' -Data @{
        Prompt = $Prompt
        Key    = $Key
    }
}

function Move-GerberCheckboxMenuFocus {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [ValidateSet('Previous', 'Next', 'First', 'Last')]
        [string]$Direction
    )
    $null = $PSCmdlet.ShouldProcess('Move-GerberCheckboxMenuFocus', 'Invoke')

    if ($State.ItemStateList.Count -eq 0) {
        $State.FocusedIndex = 0
        return
    }

    switch ($Direction) {
        'First' {
            $State.FocusedIndex = 0
            return
        }
        'Last' {
            $State.FocusedIndex = $State.ItemStateList.Count - 1
            return
        }
        'Next' {
            $State.FocusedIndex = ($State.FocusedIndex + 1) % $State.ItemStateList.Count
            return
        }
        default {
            $State.FocusedIndex = ($State.FocusedIndex + $State.ItemStateList.Count - 1) % $State.ItemStateList.Count
        }
    }
}

function Select-GerberCheckboxMenuFocusedItemState {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )
    $null = $PSCmdlet.ShouldProcess('Select-GerberCheckboxMenuFocusedItemState', 'Invoke')

    if ($State.ItemStateList.Count -eq 0) {
        return
    }

    $focusedItem = $State.ItemStateList[$State.FocusedIndex]
    $focusedItem.IsSelected = -not $focusedItem.IsSelected
}

function Get-GerberCheckboxMenuSelectedCount {
    [OutputType([int])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )
    $null = $PSCmdlet.ShouldProcess('Get-GerberCheckboxMenuSelectedCount', 'Invoke')

    return @($State.ItemStateList | Where-Object { $_.IsSelected }).Count
}

function Show-GerberCheckboxMenuRecoverableError {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ScreenTitle,

        [Parameter(Mandatory)]
        [string]$Message
    )
    $null = $PSCmdlet.ShouldProcess('Show-GerberCheckboxMenuRecoverableError', 'Invoke')

    $title = if ([string]::IsNullOrWhiteSpace($ScreenTitle)) { 'Error' } else { $ScreenTitle }
    Show-GerberTextBlock -Title $title -Text $Message
    try {
        Wait-GerberContinue
    } catch {
        if (-not (Test-GerberMenuEscapeException -Exception $_.Exception)) {
            throw
        }
    }
}

function Reset-GerberCheckboxMenuPromptRenderState {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )
    $null = $PSCmdlet.ShouldProcess('Reset-GerberCheckboxMenuPromptRenderState', 'Invoke')

    $State.RenderTop = $null
    $State.RenderedLineCount = 0
    $State.ScreenIsInitialized = $false
}

function Get-GerberCheckboxMenuPromptResult {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )
    $null = $PSCmdlet.ShouldProcess('Get-GerberCheckboxMenuPromptResult', 'Invoke')

    return [pscustomobject]@{
        SelectedItemList   = @(Get-GerberCheckboxMenuItemListBySelectionState -State $State -IsSelected $true)
        DeselectedItemList = @(Get-GerberCheckboxMenuItemListBySelectionState -State $State -IsSelected $false)
        SelectedValueList  = @((Get-GerberCheckboxMenuItemListBySelectionState -State $State -IsSelected $true) | ForEach-Object { $_.Value })
        FocusedIndex       = $State.FocusedIndex
    }
}

function Get-GerberCheckboxMenuItemListBySelectionState {
    [OutputType([object[]])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [bool]$IsSelected
    )
    $null = $PSCmdlet.ShouldProcess('Get-GerberCheckboxMenuItemListBySelectionState', 'Invoke')

    return @(
        foreach ($itemState in $State.ItemStateList) {
            if ($itemState.IsSelected -eq $IsSelected) {
                $itemState.OriginalItem
            }
        }
    )
}
