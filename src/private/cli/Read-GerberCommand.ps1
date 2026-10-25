function Read-GerberCommand {
    [CmdletBinding()]
    param(
        [string]$Prompt = '❯',

        [ValidateSet('Root', 'Subcommand', 'Static', 'None')]
        [string]$SuggestionMode = 'Root',

        [ValidateSet('Buffered', 'SelectionOnly')]
        [string]$InputMode = 'Buffered',

        [pscustomobject]$PromptContext = (ConvertTo-GerberCommandPromptContext),

        [bool]$TrimResult = $true
    )

    Clear-GerberPendingConsoleInput

    if (-not (Test-GerberInteractivePromptAvailable)) {
        Write-GerberPromptTrace -EventName 'prompt-mode' -Data @{ Prompt = $Prompt; Mode = 'ReadHost' }
        return Read-GerberHostPromptValue -Prompt $Prompt -TrimResult $TrimResult
    }

    try {
        Write-GerberPromptTrace -EventName 'prompt-mode' -Data @{ Prompt = $Prompt; Mode = 'Interactive' }
        return Read-GerberInteractiveCommand `
            -Prompt $Prompt `
            -SuggestionMode $SuggestionMode `
            -InputMode $InputMode `
            -PromptContext $PromptContext `
            -TrimResult $TrimResult
    } catch {
        if ((Test-GerberMenuEscapeException -Exception $_.Exception) -or
            (Test-GerberRootNavigationException -Exception $_.Exception)) {
            throw
        }

        Write-GerberPromptTrace -EventName 'prompt-mode' -Data @{ Prompt = $Prompt; Mode = 'ReadHostFallback'; Error = $_.Exception.Message }
        return Read-GerberHostPromptValue -Prompt $Prompt -TrimResult $TrimResult -StartOnFreshLine
    }
}

function Read-GerberHostPromptValue {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [bool]$TrimResult = $true,

        [switch]$StartOnFreshLine
    )

    if ($StartOnFreshLine) {
        Write-GerberConsoleLineBreak
    }

    Write-GerberHostPrompt -Prompt $Prompt
    return Get-GerberPromptSubmittedValue -Value (Read-Host) -TrimResult $TrimResult
}

function Write-GerberHostPrompt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt
    )

    $Host.UI.Write((Get-GerberPromptPrefix -Prompt $Prompt))
}

function Test-GerberInteractivePromptAvailable {
    [OutputType([bool])]
    [CmdletBinding()]
    param()

    try {
        if (Test-GerberConsoleInputRedirected) {
            return $false
        }

        $null = Get-GerberInteractivePromptCursorPosition
        return $true
    } catch {
        return $false
    }
}

function Read-GerberInteractiveCommand {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [ValidateSet('Root', 'Subcommand', 'Static', 'None')]
        [string]$SuggestionMode = 'Root',

        [ValidateSet('Buffered', 'SelectionOnly')]
        [string]$InputMode = 'Buffered',

        [pscustomobject]$PromptContext = (ConvertTo-GerberCommandPromptContext),

        [bool]$TrimResult = $true
    )

    $state = Initialize-GerberCommandPromptState `
        -Prompt $Prompt `
        -SuggestionMode $SuggestionMode `
        -InputMode $InputMode `
        -PromptContext $PromptContext `
        -TrimResult $TrimResult
    Sync-GerberPromptSuggestion -State $state
    Show-GerberCommandPrompt -State $state
    while ($true) {
        $key = Read-GerberMenuConsoleKey
        Write-GerberPromptTrace -EventName 'key-read' -Data (Get-GerberPromptKeyTraceData -Key $key -State $state)
        if (Test-GerberPromptEscapeRequested -Key $key) {
            Write-GerberPromptTrace -EventName 'prompt-escape' -Data @{ Buffer = $state.Buffer; CursorIndex = $state.CursorIndex }
            throw (Get-GerberMenuEscapeException)
        }

        $enterSubmitResult = Invoke-GerberEnterSubmit -State $state -Key $key
        if ($enterSubmitResult.ShouldContinue) {
            Show-GerberCommandPrompt -State $state
            continue
        }

        if ($enterSubmitResult.ShouldSubmit) {
            return $enterSubmitResult.Value
        }

        Invoke-GerberCommandPromptKey -State $state -Key $key
        Show-GerberCommandPrompt -State $state
    }
}

function Test-GerberPromptEscapeRequested {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.ConsoleKeyInfo]$Key
    )

    return $Key.Key -eq [System.ConsoleKey]::Escape
}

function Get-GerberMenuEscapeException {
    [OutputType([System.InvalidOperationException])]
    [CmdletBinding()]
    param()

    Receive-GerberEscapeContinuationKey -GraceWindowMilliseconds (Get-GerberPendingEscapeSequenceRemainingMillisecondsValue)

    if (Test-GerberPendingRootNavigationRequested) {
        Complete-GerberPendingRootNavigationRequest
        Request-GerberVisibleRootPrompt
        Clear-GerberPendingConsoleInput -Force

        $exception = [System.InvalidOperationException]::new('Return to the Gerber root menu.')
        $exception.Data['GerberRootNavigation'] = $true
        return $exception
    }

    $exception = [System.InvalidOperationException]::new('Go back to the previous Gerber menu.')
    $exception.Data['GerberMenuEscape'] = $true
    return $exception
}

function Test-GerberRootNavigationException {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [System.Exception]$Exception
    )

    if ($null -eq $Exception) {
        return $false
    }

    if ($Exception.Data.Contains('GerberRootNavigation')) {
        return [bool]$Exception.Data['GerberRootNavigation']
    }

    return Test-GerberRootNavigationException -Exception $Exception.InnerException
}

function Test-GerberMenuEscapeException {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [System.Exception]$Exception
    )

    if ($null -eq $Exception) {
        return $false
    }

    if ($Exception.Data.Contains('GerberMenuEscape')) {
        return [bool]$Exception.Data['GerberMenuEscape']
    }

    return Test-GerberMenuEscapeException -Exception $Exception.InnerException
}

function Initialize-GerberCommandPromptState {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [ValidateSet('Root', 'Subcommand', 'Static', 'None')]
        [string]$SuggestionMode = 'Root',

        [ValidateSet('Buffered', 'SelectionOnly')]
        [string]$InputMode = 'Buffered',

        [pscustomobject]$PromptContext = (ConvertTo-GerberCommandPromptContext),

        [bool]$TrimResult = $true
    )

    $suggestionCommandName = Get-GerberCommandPromptContextValue -PromptContext $PromptContext -PropertyName 'SuggestionCommandName'
    $subcommandTable = Get-GerberCommandPromptContextValue -PromptContext $PromptContext -PropertyName 'SubcommandTable'
    $staticSuggestionList = Get-GerberCommandPromptContextValue -PromptContext $PromptContext -PropertyName 'StaticSuggestionList' -DefaultValue @()
    $initialBuffer = Get-GerberCommandPromptContextValue -PromptContext $PromptContext -PropertyName 'InitialBuffer' -DefaultValue ''
    $initialCursorIndex = Get-GerberCommandPromptContextValue -PromptContext $PromptContext -PropertyName 'InitialCursorIndex' -DefaultValue $initialBuffer.Length
    $promptHintText = Get-GerberCommandPromptContextValue -PromptContext $PromptContext -PropertyName 'PromptHintText'
    $emptyStateHintText = Get-GerberCommandPromptContextValue -PromptContext $PromptContext -PropertyName 'EmptyStateHintText'
    $autoSelectFirstSuggestionOnSubmit = Get-GerberCommandPromptContextValue -PromptContext $PromptContext -PropertyName 'AutoSelectFirstSuggestionOnSubmit' -DefaultValue $false
    $resolvedInitialCursorIndex = Resolve-GerberInitialCursorIndex -InitialBuffer $initialBuffer -InitialCursorIndex $initialCursorIndex

    return @{
        Prompt = $Prompt
        SuggestionMode = $SuggestionMode
        InputMode = $InputMode
        TrimResult = $TrimResult
        SuggestionCommandName = $suggestionCommandName
        SuggestionSubcommandTable = $subcommandTable
        StaticSuggestionList = @($StaticSuggestionList)
        InitialBuffer = $initialBuffer
        InitialCursorIndex = $resolvedInitialCursorIndex
        PromptHintText = $promptHintText
        EmptyStateHintText = $emptyStateHintText
        AutoSelectFirstSuggestionOnSubmit = $autoSelectFirstSuggestionOnSubmit
        Buffer = $InitialBuffer
        CursorIndex = $resolvedInitialCursorIndex
        SuggestionIndex = 0
        SuggestionList = @()
        SuggestionNavigationUsed = $false
        RenderedLineCount = 0
        PromptTop = Get-GerberConsoleCursorTop
    }
}

function Resolve-GerberInitialCursorIndex {
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$InitialBuffer = '',

        [int]$InitialCursorIndex = -1
    )

    if ($InitialCursorIndex -lt 0) {
        return $InitialBuffer.Length
    }

    return [Math]::Min($InitialCursorIndex, $InitialBuffer.Length)
}

function Invoke-GerberEnterSubmit {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [System.ConsoleKeyInfo]$Key
    )

    if ($Key.Key -ne [System.ConsoleKey]::Enter) {
        return [pscustomobject]@{
            ShouldContinue = $false
            ShouldSubmit = $false
            Value = $null
        }
    }

    if (Submit-GerberPromptSuggestion -State $State) {
        return [pscustomobject]@{
            ShouldContinue = $true
            ShouldSubmit = $false
            Value = $null
        }
    }

    if (Enter-GerberPromptSubcommandScope -State $State) {
        return [pscustomobject]@{
            ShouldContinue = $true
            ShouldSubmit = $false
            Value = $null
        }
    }

    Write-GerberPromptTrace -EventName 'prompt-submit' -Data @{ Buffer = $State.Buffer; CursorIndex = $State.CursorIndex }
    Complete-GerberPrompt -State $State
    return [pscustomobject]@{
        ShouldContinue = $false
        ShouldSubmit = $true
        Value = Get-GerberPromptSubmittedValue `
            -Value $State.Buffer `
            -TrimResult (Get-GerberPromptStateValue -State $State -PropertyName 'TrimResult' -DefaultValue $true)
    }
}

function Get-GerberPromptSubmittedValue {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Value,

        [bool]$TrimResult = $true
    )

    if ($TrimResult -and $null -ne $Value) {
        return $Value.Trim()
    }

    return $Value
}

function Invoke-GerberCommandPromptKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [System.ConsoleKeyInfo]$Key
    )

    if (Test-GerberHandledSuggestionKey -State $State -Key $Key) {
        return
    }

    if (Test-GerberHandledCursorKey -State $State -Key $Key) {
        return
    }

    if (Test-GerberHandledBufferKey -State $State -Key $Key) {
        Sync-GerberPromptSuggestion -State $State
    }
}

function Test-GerberHandledSuggestionKey {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [System.ConsoleKeyInfo]$Key
    )

    if (Test-GerberTabKey -Key $Key) {
        Write-GerberPromptTrace -EventName 'suggestion-key' -Data @{ Key = 'Tab'; Buffer = $State.Buffer; SuggestionCount = $State.SuggestionList.Count }
        return Complete-GerberPromptSuggestion -State $State
    }

    switch ($Key.Key) {
        ([System.ConsoleKey]::UpArrow) {
            $State.SuggestionIndex = Get-GerberPromptSelectionIndex -State $State -Direction 'Previous'
            $State.SuggestionNavigationUsed = ($State.SuggestionList.Count -gt 0)
            Write-GerberPromptTrace -EventName 'suggestion-key' -Data @{ Key = 'UpArrow'; SuggestionIndex = $State.SuggestionIndex; SuggestionCount = $State.SuggestionList.Count }
            return ($State.SuggestionList.Count -gt 0)
        }
        ([System.ConsoleKey]::DownArrow) {
            $State.SuggestionIndex = Get-GerberPromptSelectionIndex -State $State -Direction 'Next'
            $State.SuggestionNavigationUsed = ($State.SuggestionList.Count -gt 0)
            Write-GerberPromptTrace -EventName 'suggestion-key' -Data @{ Key = 'DownArrow'; SuggestionIndex = $State.SuggestionIndex; SuggestionCount = $State.SuggestionList.Count }
            return ($State.SuggestionList.Count -gt 0)
        }
        default {
            return $false
        }
    }
}

function Test-GerberTabKey {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.ConsoleKeyInfo]$Key
    )

    if ($Key.Key -eq [System.ConsoleKey]::Tab) {
        return $true
    }

    return $Key.KeyChar -eq [char]9
}

function Test-GerberHandledCursorKey {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [System.ConsoleKeyInfo]$Key
    )

    switch ($Key.Key) {
        ([System.ConsoleKey]::LeftArrow) {
            $State.CursorIndex = [Math]::Max(0, $State.CursorIndex - 1)
            return $true
        }
        ([System.ConsoleKey]::RightArrow) {
            $State.CursorIndex = [Math]::Min($State.Buffer.Length, $State.CursorIndex + 1)
            return $true
        }
        ([System.ConsoleKey]::Home) {
            $State.CursorIndex = 0
            return $true
        }
        ([System.ConsoleKey]::End) {
            $State.CursorIndex = $State.Buffer.Length
            return $true
        }
        default {
            return $false
        }
    }
}

function Test-GerberHandledBufferKey {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [System.ConsoleKeyInfo]$Key
    )

    if ((Get-GerberPromptStateValue -State $State -PropertyName 'InputMode' -DefaultValue 'Buffered') -eq 'SelectionOnly') {
        return $false
    }

    switch ($Key.Key) {
        ([System.ConsoleKey]::Backspace) {
            return Edit-GerberPromptCharacterAtIndex -State $State -DeleteIndex ($State.CursorIndex - 1)
        }
        ([System.ConsoleKey]::Delete) {
            return Edit-GerberPromptCharacterAtIndex -State $State -DeleteIndex $State.CursorIndex
        }
        default {
            return Add-GerberPromptCharacter -State $State -Key $Key
        }
    }
}

function Complete-GerberPromptSuggestion {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    if ($State.SuggestionList.Count -eq 0) {
        Sync-GerberPromptSuggestion -State $State
    }

    if ($State.SuggestionList.Count -eq 0) {
        Write-GerberPromptTrace -EventName 'suggestion-apply' -Data @{ Applied = $false; Buffer = $State.Buffer; Reason = 'NoSuggestions' }
        return $false
    }

    $selectedSuggestion = $State.SuggestionList[$State.SuggestionIndex]
    Write-GerberPromptTrace -EventName 'suggestion-apply' -Data @{
        Applied = $true
        Buffer = $State.Buffer
        SuggestionIndex = $State.SuggestionIndex
        CompletionText = $selectedSuggestion.CompletionText
    }
    $previousScopeKey = Get-GerberPromptSuggestionScopeKey -State $State -InputText $State.Buffer
    $State.Buffer = $selectedSuggestion.CompletionText
    $State.CursorIndex = $State.Buffer.Length
    Sync-GerberPromptSuggestion -State $State
    Restore-GerberPromptSuggestionSelection -State $State -PreviousScopeKey $previousScopeKey
    return $true
}

function Submit-GerberPromptSuggestion {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    if (-not (Test-GerberShouldApplySuggestionOnSubmit -State $State)) {
        return $false
    }

    if (-not (Complete-GerberPromptSuggestion -State $State)) {
        return $false
    }

    Write-GerberPromptTrace -EventName 'prompt-submit-selection' -Data @{
        Buffer = $State.Buffer
        CursorIndex = $State.CursorIndex
        HasMoreSuggestions = ($State.SuggestionList.Count -gt 0)
    }

    if (Enter-GerberPromptSubcommandScope -State $State) {
        return $true
    }

    return (Test-GerberPromptSelectionContinue -State $State)
}

function Test-GerberShouldApplySuggestionOnSubmit {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    if ($State.SuggestionList.Count -eq 0) {
        return $false
    }

    if ((Get-GerberPromptStateValue -State $State -PropertyName 'InputMode' -DefaultValue 'Buffered') -eq 'SelectionOnly') {
        return $State.SuggestionNavigationUsed -or (Test-GerberSelectionOnlyAutoFirstSelect -State $State)
    }

    if ($State.SuggestionNavigationUsed) {
        return $true
    }

    if (Test-GerberPromptAutoSelectOnSubmit -State $State) {
        return $true
    }

    $suggestionMode = Get-GerberPromptSuggestionMode -State $State
    $resolution = Resolve-GerberPromptInput `
        -InputText $State.Buffer `
        -SuggestionMode $suggestionMode `
        -SuggestionCommandName (Get-GerberPromptStateValue -State $State -PropertyName 'SuggestionCommandName') `
        -SuggestionSubcommandTable (Get-GerberPromptStateValue -State $State -PropertyName 'SuggestionSubcommandTable')
    return -not $resolution.IsValid
}

function Test-GerberSelectionOnlyAutoFirstSelect {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    if (-not (Get-GerberPromptStateValue -State $State -PropertyName 'AutoSelectFirstSuggestionOnSubmit' -DefaultValue $false)) {
        return $false
    }

    return [string]::IsNullOrWhiteSpace($State.Buffer)
}

function Test-GerberPromptAutoSelectOnSubmit {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    if (-not (Get-GerberPromptStateValue -State $State -PropertyName 'AutoSelectFirstSuggestionOnSubmit' -DefaultValue $false)) {
        return $false
    }

    $initialBuffer = Get-GerberPromptStateValue -State $State -PropertyName 'InitialBuffer' -DefaultValue ''
    if ([string]::IsNullOrWhiteSpace($initialBuffer)) {
        return $false
    }

    return $State.Buffer -eq $initialBuffer
}

function Get-GerberPromptSuggestionMode {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    if ($State.ContainsKey('SuggestionMode') -and -not [string]::IsNullOrWhiteSpace($State.SuggestionMode)) {
        return $State.SuggestionMode
    }

    return 'Root'
}

function Get-GerberPromptStateValue {
    [OutputType([object])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [string]$PropertyName,

        [object]$DefaultValue = $null
    )

    if (-not $State.ContainsKey($PropertyName)) {
        return $DefaultValue
    }

    return $State[$PropertyName]
}

function Enter-GerberPromptSubcommandScope {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    if ((Get-GerberPromptSuggestionMode -State $State) -ne 'Root') {
        return $false
    }

    $resolution = Resolve-GerberCommand -InputText $State.Buffer
    if (-not (Test-GerberPromptSubcommandEntry -Resolution $resolution)) {
        return $false
    }

    $commandDefinition = Get-GerberRegisteredCommand -Name $resolution.Name
    if ($null -eq $commandDefinition) {
        return $false
    }

    $promptContext = ConvertTo-GerberSubcommandPromptContext `
        -CommandName $resolution.Name `
        -SubcommandTable $commandDefinition.Subcommands
    $State.SuggestionMode = 'Subcommand'
    $State.SuggestionCommandName = $promptContext.SuggestionCommandName
    $State.InitialBuffer = $promptContext.InitialBuffer
    $State.InitialCursorIndex = Resolve-GerberInitialCursorIndex `
        -InitialBuffer $promptContext.InitialBuffer `
        -InitialCursorIndex (Get-GerberCommandPromptContextValue -PromptContext $promptContext -PropertyName 'InitialCursorIndex' -DefaultValue $promptContext.InitialBuffer.Length)
    $State.PromptHintText = $promptContext.PromptHintText
    $State.Buffer = $promptContext.InitialBuffer
    $State.CursorIndex = $State.InitialCursorIndex
    $State.SuggestionIndex = 0
    Sync-GerberPromptSuggestion -State $State
    $State.SuggestionNavigationUsed = ($State.SuggestionList.Count -gt 0)
    Write-GerberPromptTrace -EventName 'prompt-subcommand-entry' -Data @{
        CommandName = $resolution.Name
        Buffer = $State.Buffer
        SuggestionCount = $State.SuggestionList.Count
    }

    return $true
}

function Test-GerberPromptSubcommandEntry {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Resolution
    )

    if (-not $Resolution.IsValid) {
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($Resolution.Name)) {
        return $false
    }

    if ((Get-GerberCollectionCount -InputObject $Resolution.Arguments) -gt 0) {
        return $false
    }

    $commandDefinition = Get-GerberRegisteredCommand -Name $Resolution.Name
    if ($null -eq $commandDefinition) {
        return $false
    }

    return Test-GerberCommandHasSubcommandMenu -CommandData ([hashtable]@{
            Description = $commandDefinition.Description
            Subcommands = $commandDefinition.Subcommands
        })
}

function Edit-GerberPromptCharacterAtIndex {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [int]$DeleteIndex
    )

    if ($DeleteIndex -lt 0 -or $DeleteIndex -ge $State.Buffer.Length) {
        return $false
    }

    $State.Buffer = $State.Buffer.Remove($DeleteIndex, 1)
    $State.CursorIndex = [Math]::Min($DeleteIndex, $State.Buffer.Length)
    return $true
}

function Add-GerberPromptCharacter {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [System.ConsoleKeyInfo]$Key
    )

    if ([char]::IsControl($Key.KeyChar)) {
        return $false
    }

    $State.Buffer = $State.Buffer.Insert($State.CursorIndex, [string]$Key.KeyChar)
    $State.CursorIndex++
    return $true
}

function Move-GerberSuggestionSelection {
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$CurrentIndex,

        [Parameter(Mandatory)]
        [int]$SuggestionCount,

        [Parameter(Mandatory)]
        [string]$Direction
    )

    if ($SuggestionCount -eq 0) {
        return 0
    }

    if ($Direction -eq 'Previous') {
        return (($CurrentIndex - 1) + $SuggestionCount) % $SuggestionCount
    }

    return ($CurrentIndex + 1) % $SuggestionCount
}

function Sync-GerberPromptSuggestion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    Restore-GerberPromptRootScope -State $State | Out-Null
    $suggestionMode = Get-GerberPromptSuggestionMode -State $State
    $resolution = if ($suggestionMode -eq 'Static') {
        [pscustomobject]@{
            IsValid = $true
            ErrorMessage = $null
            Suggestions = @(Get-GerberPromptStateValue -State $State -PropertyName 'StaticSuggestionList' -DefaultValue @())
        }
    } else {
        Resolve-GerberPromptInput `
            -InputText $State.Buffer `
            -SuggestionMode $suggestionMode `
            -SuggestionCommandName (Get-GerberPromptStateValue -State $State -PropertyName 'SuggestionCommandName') `
            -SuggestionSubcommandTable (Get-GerberPromptStateValue -State $State -PropertyName 'SuggestionSubcommandTable')
    }
    $State.SuggestionList = @($resolution.Suggestions)
    $State.SuggestionNavigationUsed = $false
    Write-GerberPromptTrace -EventName 'suggestion-sync' -Data @{
        Buffer = $State.Buffer
        SuggestionMode = $suggestionMode
        IsValid = $resolution.IsValid
        ErrorMessage = $resolution.ErrorMessage
        SuggestionList = @($State.SuggestionList | Select-Object -ExpandProperty DisplayText)
    }
    if ($State.SuggestionList.Count -eq 0) {
        $State.SuggestionIndex = 0
        return
    }

    $State.SuggestionIndex = [Math]::Min($State.SuggestionIndex, $State.SuggestionList.Count - 1)
}
