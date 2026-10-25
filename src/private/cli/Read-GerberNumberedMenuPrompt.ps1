function Read-GerberNumberedMenuPrompt {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [string]$ScreenTitle,

        [string]$ScreenText,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$MenuItemList
    )

    $state = Initialize-GerberNumberedMenuPromptState -MenuItemList @($MenuItemList)
    Write-GerberPromptTrace -EventName 'numbered-open' -Data @{
        Prompt    = $Prompt
        ItemCount = $state.MenuItemList.Count
    }

    while ($true) {
        Show-GerberNumberedMenuPrompt `
            -Prompt $Prompt `
            -ScreenTitle $ScreenTitle `
            -ScreenText $ScreenText `
            -State $state
        $key = Read-GerberMenuConsoleKey
        Write-GerberPromptTrace -EventName 'numbered-key-read' -Data @{
            Prompt       = $Prompt
            Key          = $key.Key.ToString()
            KeyChar      = [int][char]$key.KeyChar
            FocusedIndex = $state.FocusedIndex
        }

        if (Test-GerberPromptEscapeRequested -Key $key) {
            Write-GerberPromptTrace -EventName 'numbered-cancel' -Data @{
                Prompt       = $Prompt
                FocusedIndex = $state.FocusedIndex
            }
            throw (Get-GerberMenuEscapeException)
        }

        $selectionResult = Get-GerberNumberedMenuPromptSelectionResult -State $state -Key $key
        if ($selectionResult.ShouldSubmit) {
            Write-GerberPromptTrace -EventName 'numbered-submit' -Data @{
                Prompt       = $Prompt
                FocusedIndex = $state.FocusedIndex
                Value        = $selectionResult.Value
            }
            return $selectionResult.Value
        }

        if (Move-GerberNumberedMenuFocusIfRequested -Prompt $Prompt -State $state -Key $key) {
            continue
        }

        Write-GerberPromptTrace -EventName 'numbered-key-ignored' -Data @{
            Prompt = $Prompt
            Key    = $key.Key.ToString()
        }
    }
}

function Initialize-GerberNumberedMenuPromptState {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$MenuItemList
    )

    return @{
        FocusedIndex       = 0
        MenuItemList       = @($MenuItemList)
        RenderTop          = $null
        RenderedLineCount  = 0
        ScreenIsInitialized = $false
    }
}

function Show-GerberNumberedMenuPrompt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [string]$ScreenTitle,

        [string]$ScreenText,

        [Parameter(Mandatory)]
        [hashtable]$State
    )

    if (-not $State.ScreenIsInitialized) {
        Show-GerberNumberedMenuPromptScreen -ScreenTitle $ScreenTitle -ScreenText $ScreenText
        $State.ScreenIsInitialized = $true
    }

    $lineList = @(Get-GerberNumberedMenuPromptLineList -Prompt $Prompt -State $State)
    $renderResult = Show-GerberRenderRegion -State $State -LineList $lineList
    Write-GerberPromptTrace -EventName 'numbered-render' -Data @{
        Prompt                 = $Prompt
        FocusedIndex           = $State.FocusedIndex
        RenderTop              = $renderResult.RenderTop
        PreviousRenderedLines  = $renderResult.PreviousRenderedLines
        NewRenderedLines       = $renderResult.NewRenderedLines
        ItemCount              = $State.MenuItemList.Count
        Width                  = Get-GerberPromptTraceWidthOrNull
        UsedFallback           = $renderResult.UsedFallback
    }
}

function Get-GerberNumberedMenuPromptLineList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter(Mandatory)]
        [hashtable]$State
    )

    $lineList = [System.Collections.Generic.List[pscustomobject]]::new()
    $lineList.Add((ConvertTo-GerberPromptRenderLine -Text "$Prompt`:"))
    foreach ($line in @(Get-GerberNumberedMenuItemLineList -State $State)) {
        $lineList.Add($line)
    }
    foreach ($line in @(Get-GerberNumberedMenuPreviewLineList -State $State)) {
        $lineList.Add($line)
    }

    return @($lineList)
}

function Get-GerberNumberedMenuItemLineList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    if ($State.MenuItemList.Count -eq 0) {
        return @(ConvertTo-GerberPromptRenderLine -Text '  - None')
    }

    return @(
        foreach ($index in 0..($State.MenuItemList.Count - 1)) {
            $menuItem = $State.MenuItemList[$index]
            $isFocused = $index -eq $State.FocusedIndex
            $prefix = if ($isFocused) { [string][char]0x276F } else { ' ' }
            ConvertTo-GerberPromptRenderLine `
                -Text ("  {0} {1}. {2}" -f $prefix, $menuItem.Number, $menuItem.Label) `
                -IsSelected $isFocused
        }
    )
}

function Get-GerberNumberedMenuPreviewLineList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    if ($State.MenuItemList.Count -eq 0) {
        return @()
    }

    $previewText = [string]$State.MenuItemList[$State.FocusedIndex].PreviewText
    if ([string]::IsNullOrWhiteSpace($previewText)) {
        return @()
    }

    return @(
        ConvertTo-GerberPromptRenderLine -Text ("  Preview: {0}" -f $previewText)
    )
}

function Get-GerberNumberedMenuPromptSelectionResult {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [System.ConsoleKeyInfo]$Key
    )

    if ($Key.Key -eq [System.ConsoleKey]::Enter) {
        return Get-GerberNumberedMenuEnterSelectionResult -State $State
    }

    $shortcutSelectionResult = Get-GerberNumberedMenuShortcutSelectionResultOrNull `
        -MenuItemList @($State.MenuItemList) `
        -Key $Key
    if ($null -ne $shortcutSelectionResult) {
        return $shortcutSelectionResult
    }

    return [pscustomobject]@{
        ShouldSubmit = $false
        Value        = ''
    }
}

function Get-GerberNumberedMenuEnterSelectionResult {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    if ($State.MenuItemList.Count -eq 0) {
        return [pscustomobject]@{
            ShouldSubmit = $false
            Value        = ''
        }
    }

    return [pscustomobject]@{
        ShouldSubmit = $true
        Value        = [string]$State.MenuItemList[$State.FocusedIndex].Value
    }
}

function Get-GerberNumberedMenuShortcutSelectionResultOrNull {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$MenuItemList,

        [Parameter(Mandatory)]
        [System.ConsoleKeyInfo]$Key
    )

    if (-not [char]::IsDigit($Key.KeyChar)) {
        return $null
    }

    $selectedItem = Get-GerberNumberedMenuPromptItemByNumberOrNull `
        -MenuItemList $MenuItemList `
        -Number ([string]$Key.KeyChar)
    if ($null -eq $selectedItem) {
        return $null
    }

    return [pscustomobject]@{
        ShouldSubmit = $true
        Value        = [string]$selectedItem.Value
    }
}

function Get-GerberNumberedMenuPromptItemByNumberOrNull {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$MenuItemList,

        [Parameter(Mandatory)]
        [string]$Number
    )

    foreach ($menuItem in @($MenuItemList)) {
        if ([string]$menuItem.Number -eq $Number) {
            return $menuItem
        }
    }

    return $null
}

function Move-GerberNumberedMenuFocusIfRequested {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [System.ConsoleKeyInfo]$Key
    )

    $direction = Get-GerberNumberedMenuFocusDirection -Key $Key
    if ([string]::IsNullOrWhiteSpace($direction)) {
        return $false
    }

    Move-GerberNumberedMenuFocus -State $State -Direction $direction
    Write-GerberPromptTrace -EventName 'numbered-focus' -Data @{
        Prompt       = $Prompt
        Direction    = $direction
        FocusedIndex = $State.FocusedIndex
    }
    return $true
}

function Get-GerberNumberedMenuFocusDirection {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.ConsoleKeyInfo]$Key
    )

    switch ($Key.Key) {
        ([System.ConsoleKey]::UpArrow) { return 'Previous' }
        ([System.ConsoleKey]::DownArrow) { return 'Next' }
        ([System.ConsoleKey]::Home) { return 'First' }
        ([System.ConsoleKey]::End) { return 'Last' }
        default { return '' }
    }
}

function Move-GerberNumberedMenuFocus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [ValidateSet('Previous', 'Next', 'First', 'Last')]
        [string]$Direction
    )

    if ($State.MenuItemList.Count -eq 0) {
        $State.FocusedIndex = 0
        return
    }

    switch ($Direction) {
        'First' {
            $State.FocusedIndex = 0
            return
        }
        'Last' {
            $State.FocusedIndex = $State.MenuItemList.Count - 1
            return
        }
        'Previous' {
            $State.FocusedIndex = if ($State.FocusedIndex -le 0) {
                $State.MenuItemList.Count - 1
            } else {
                $State.FocusedIndex - 1
            }
            return
        }
        'Next' {
            $State.FocusedIndex = ($State.FocusedIndex + 1) % $State.MenuItemList.Count
            return
        }
    }
}

function Show-GerberNumberedMenuPromptScreen {
    [CmdletBinding()]
    param(
        [string]$ScreenTitle,

        [string]$ScreenText
    )

    if ([string]::IsNullOrWhiteSpace($ScreenTitle)) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($ScreenText)) {
        Start-GerberScreen -Name $ScreenTitle
        Write-GerberScreenLine -Text $ScreenTitle
        Write-GerberScreenLine
        return
    }

    Show-GerberTextBlock -Title $ScreenTitle -Text $ScreenText
}

function ConvertTo-GerberNumberedMenuSuggestionList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$MenuItemList
    )

    return @(
        foreach ($menuItem in $MenuItemList) {
            ConvertTo-GerberSuggestion `
                -DisplayText ("{0}. {1}" -f $menuItem.Number, $menuItem.Label) `
                -CompletionText $menuItem.Value `
                -PreviewText $menuItem.PreviewText
        }
    )
}
