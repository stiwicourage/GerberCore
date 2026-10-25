function Show-GerberSecretsView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Command
    )

    $actionTable = Get-GerberSecretsActionTable
    $currentCommand = $Command
    while ($true) {
        $action = Read-GerberSecretsAction -CurrentCommand $currentCommand -ActionTable $actionTable
        if ($null -eq $action) {
            return
        }

        if ([string]::IsNullOrWhiteSpace($action)) {
            return
        }

        Write-GerberPromptTrace -EventName 'secrets-action-selected' -Data @{ Action = $action }
        $currentCommand = Invoke-GerberSecretsActionLoop -Action $action -ActionTable $actionTable
    }
}

function Read-GerberSecretsAction {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$CurrentCommand,

        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary]$ActionTable
    )

    try {
        return Get-GerberMenuSubcommand `
            -CommandName 'secrets' `
            -Command $CurrentCommand `
            -SubcommandTable $ActionTable `
            -AutoSelectFirstSuggestionOnSubmit
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) {
            Write-GerberPromptTrace -EventName 'secrets-menu-back' -Data @{}
            return $null
        }

        throw
    }
}

function Invoke-GerberSecretsActionLoop {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary]$ActionTable
    )

    try {
        Write-GerberPromptTrace -EventName 'secrets-action-start' -Data @{ Action = $Action }
        Invoke-GerberSecretsAction -Action $Action
        Write-GerberPromptTrace -EventName 'secrets-action-complete' -Data @{ Action = $Action }
        Wait-GerberContinue
        return Get-GerberSecretsNextCommand -Action $Action -ActionTable $ActionTable
    } catch [System.ArgumentException] {
        Write-GerberPromptTrace -EventName 'secrets-action-error' -Data @{
            Action = $Action
            ErrorType = 'Argument'
        }
        return Resolve-GerberSecretsArgumentError -Action $Action -ActionTable $ActionTable -Exception $_.Exception
    } catch {
        if (-not (Test-GerberMenuEscapeException -Exception $_.Exception)) {
            throw
        }

        Write-GerberPromptTrace -EventName 'secrets-action-back' -Data @{ Action = $Action }
        return ConvertTo-GerberNestedCommand
    }
}

function Resolve-GerberSecretsArgumentError {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary]$ActionTable,

        [Parameter(Mandatory)]
        [System.ArgumentException]$Exception
    )

    Show-GerberTextBlock -Title 'Error' -Text $Exception.Message
    try {
        Wait-GerberContinue
        return Get-GerberSecretsNextCommand -Action $Action -ActionTable $ActionTable
    } catch {
        if (-not (Test-GerberMenuEscapeException -Exception $_.Exception)) {
            throw
        }

        return ConvertTo-GerberNestedCommand
    }
}

function Get-GerberSecretsActionTable {
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    [CmdletBinding()]
    param()

    return [ordered]@{
        list = 'Show the stored Gerber keys'
        get = 'Reveal a stored Gerber key after confirmation'
        test = 'Check whether a Gerber credential exists'
        set = 'Create or overwrite a stored Gerber secret'
        remove = 'Remove a stored Gerber secret'
    }
}

function Invoke-GerberSecretsAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Action
    )

    $actionHandlerTable = Get-GerberSecretsActionHandlerTable
    if (-not $actionHandlerTable.Contains($Action)) {
        throw [System.ArgumentException]::new("Unknown secrets action '$Action'. Use /secrets list, get, test, set, or remove.")
    }

    & $actionHandlerTable[$Action]
}

function Get-GerberSecretsActionHandlerTable {
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    [CmdletBinding()]
    param()

    return [ordered]@{
        list = { Invoke-GerberSecretsList }
        get = { Invoke-GerberSecretsGet }
        test = { Invoke-GerberSecretsTest }
        set = { Invoke-GerberSecretsSet }
        remove = { Invoke-GerberSecretsRemove }
    }
}

function Invoke-GerberSecretsList {
    [CmdletBinding()]
    param()

    $credentialInfoList = @(Get-GerberCredentialInfo)
    if ($credentialInfoList.Count -eq 0) {
        Show-GerberTextBlock -Title '/secrets list' -Text 'No Gerber-owned credentials are stored.'
        return
    }

    Show-GerberTextBlock -Title '/secrets list' -Text (@(
            'Stored Gerber credentials'
            ''
            (Format-GerberCredentialInfoList -InfoList $credentialInfoList)
        ) -join [Environment]::NewLine)
}

function Format-GerberCredentialInfoList {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$InfoList
    )

    return @(
        foreach ($credentialInfo in $InfoList) {
            [string]$credentialInfo.Identifier
        }
    ) -join [Environment]::NewLine
}

function Invoke-GerberSecretsGet {
    [CmdletBinding()]
    param()

    $nameList = Get-GerberStoredSecretNameList
    if (@($nameList).Count -eq 0) {
        Show-GerberTextBlock -Title '/secrets get' -Text 'No Gerber-owned credentials are stored.'
        return
    }

    Show-GerberSecretsStoredNameListScreen -Action 'get' -NameList $nameList
    $name = Read-GerberOwnedSecretName -Prompt 'Gerber secret name'
    Assert-GerberStoredSecret -Name $name

    $result = Get-GerberSecretRevealResult -Name $name
    $shouldReveal = Read-GerberConfirmationPrompt `
        -ScreenTitle '/secrets get' `
        -Prompt "Reveal '$name' in the terminal?" `
        -PromptOptionSet (Get-GerberConfirmationPromptOptionSet `
            -ActionLabel 'Reveal secret value' `
            -CancelLabel 'Cancel' `
            -ActionPreviewText (Get-GerberSecretRevealPreviewText -ClipboardResult $result.ClipboardResult) `
            -CancelPreviewText (Get-GerberSecretHidePreviewText -ClipboardResult $result.ClipboardResult))
    if (-not $shouldReveal) {
        Show-GerberTextBlock -Title '/secrets get' -Text (Format-GerberSecretHiddenText -ClipboardResult $result.ClipboardResult)
        return
    }

    Show-GerberTextBlock -Title '/secrets get' -Text (Format-GerberSecretRevealText -Name $name -Result $result)
}

function Invoke-GerberSecretsSet {
    [CmdletBinding()]
    param()

    Show-GerberSecretsActionScreen -Action 'set'
    $name = Read-GerberOwnedSecretName -Prompt 'Gerber secret name' -PreloadTemplate
    if (Test-GerberStoredSecret -Name $name) {
        $shouldOverwrite = Read-GerberConfirmationPrompt `
            -ScreenTitle '/secrets set' `
            -Prompt "Overwrite '$name'?" `
            -PromptOptionSet (Get-GerberConfirmationPromptOptionSet `
                -ActionLabel 'Overwrite secret' `
                -CancelLabel 'Cancel' `
                -ActionPreviewText 'Replace the stored secret value.' `
                -CancelPreviewText 'Leave the existing secret unchanged.')
        if (-not $shouldOverwrite) {
            Show-GerberTextBlock -Title '/secrets set' -Text 'Gerber left the existing secret unchanged.'
            return
        }
    }

    $secretValue = ConvertTo-GerberSecretText -Value (Read-GerberSecureValue -Prompt 'Secret value')
    Set-GerberCredential -Identifier $name -Secret $secretValue | Out-Null
    Show-GerberTextBlock -Title '/secrets set' -Text "Stored credential '$name' in secure credential storage."
}

function Invoke-GerberSecretsRemove {
    [CmdletBinding()]
    param()

    $nameList = Get-GerberStoredSecretNameList
    if (@($nameList).Count -eq 0) {
        Show-GerberTextBlock -Title '/secrets remove' -Text 'No Gerber-owned credentials are stored.'
        return
    }

    Show-GerberSecretsStoredNameListScreen -Action 'remove' -NameList $nameList
    $name = Read-GerberOwnedSecretName -Prompt 'Gerber secret name'
    Assert-GerberStoredSecret -Name $name

    $shouldRemove = Read-GerberConfirmationPrompt `
        -ScreenTitle '/secrets remove' `
        -Prompt "Remove '$name'?" `
        -PromptOptionSet (Get-GerberConfirmationPromptOptionSet `
            -ActionLabel 'Remove secret' `
            -CancelLabel 'Cancel' `
            -ActionPreviewText 'Delete the stored secret.' `
            -CancelPreviewText 'Keep the stored secret.')
    if (-not $shouldRemove) {
        Show-GerberTextBlock -Title '/secrets remove' -Text 'Gerber left the stored secret unchanged.'
        return
    }

    Remove-GerberCredential -Identifier $name | Out-Null
    Show-GerberTextBlock -Title '/secrets remove' -Text "Removed credential '$name' from secure credential storage."
}

function Invoke-GerberSecretsTest {
    [CmdletBinding()]
    param()

    Show-GerberSecretsActionScreen -Action 'test'
    $name = Read-GerberOwnedSecretName -Prompt 'Gerber credential identifier'
    $status = if (Test-GerberCredential -Identifier $name) { 'Stored' } else { 'Not stored' }
    $text = @(
        'Credential identifier'
        $name
        ''
        'Status'
        $status
    ) -join [Environment]::NewLine
    Show-GerberTextBlock -Title '/secrets test' -Text $text
}

function Show-GerberSecretsActionScreen {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Action
    )

    Start-GerberScreen -Name "/secrets $Action"
    Write-GerberScreenLine -Text "/secrets $Action"
    Write-GerberScreenLine
}

function Show-GerberSecretsStoredNameListScreen {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [string[]]$NameList
    )

    Show-GerberSecretsActionScreen -Action $Action
    Write-GerberScreenLine -Text (Get-GerberStoredSecretHeading)
    Write-GerberScreenLine
    foreach ($name in $NameList) {
        Write-GerberScreenLine -Text $name
    }

    Write-GerberScreenLine
}

function Get-GerberStoredSecretHeading {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    return 'Stored Gerber keys'
}

function Read-GerberOwnedSecretName {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [switch]$PreloadTemplate
    )

    $promptArguments = @{
        Prompt = $Prompt
        SuggestionMode = 'None'
    }
    if ($PreloadTemplate) {
        $promptArguments.PromptContext = Get-GerberOwnedSecretNamePromptContext
    }

    $name = Read-GerberCommand @promptArguments
    if (-not (Test-GerberOwnedSecretName -Name $name)) {
        throw [System.ArgumentException]::new(
            "Use a Gerber-owned secret name like '$(Get-GerberOwnedSecretNameTemplate)'."
        )
    }

    return $name.Trim()
}

function Get-GerberOwnedSecretNamePromptContext {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param()

    $template = Get-GerberOwnedSecretNameTemplate
    return ConvertTo-GerberCommandPromptContext `
        -InitialBuffer $template `
        -InitialCursorIndex (Get-GerberOwnedSecretNameTemplatePlaceholderIndex -Template $template)
}

function Get-GerberOwnedSecretNameTemplate {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    return 'gerber:<scope>:<name>'
}

function Get-GerberOwnedSecretNameTemplatePlaceholderIndex {
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Template
    )

    return $Template.IndexOf('<', [System.StringComparison]::Ordinal)
}

function Test-GerberOwnedSecretName {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $false
    }

    try {
        $null = Resolve-GerberCredentialIdentifier -Identifier $Name
        return $true
    } catch [System.ArgumentException] {
        return $false
    }
}

function Get-GerberStoredSecretNameList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param()

    return [string[]]@(
        Get-GerberCredentialInfo |
            ForEach-Object { $_.Identifier }
    )
}

function Assert-GerberStoredSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    if (-not (Test-GerberStoredSecret -Name $Name)) {
        throw [System.ArgumentException]::new("Gerber did not find credential '$Name' in secure credential storage.")
    }
}

function Test-GerberStoredSecret {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    return Test-GerberCredential -Identifier $Name
}

function Get-GerberSecretValueText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    return Get-GerberCredential -Identifier $Name
}

function Get-GerberSecretRevealResult {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $value = Get-GerberSecretValueText -Name $Name
    return [pscustomobject]@{
        Value = $value
        ClipboardResult = Copy-GerberValueToClipboard -Value $value
    }
}

function Format-GerberSecretRevealText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [pscustomobject]$Result
    )

    return @(
        'Secret name'
        $Name
        ''
        'Secret value'
        (Get-GerberSecretDisplayText -Value $Result.Value)
        ''
        'Clipboard'
        (Get-GerberSecretClipboardStatusMessage -ClipboardResult $Result.ClipboardResult)
    ) -join [Environment]::NewLine
}

function Format-GerberSecretHiddenText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$ClipboardResult
    )

    return @(
        'Gerber kept the secret value hidden in the terminal.'
        ''
        'Clipboard'
        (Get-GerberSecretClipboardStatusMessage -ClipboardResult $ClipboardResult)
    ) -join [Environment]::NewLine
}

function Get-GerberSecretRevealPreviewText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$ClipboardResult
    )

    if ($ClipboardResult.Success) {
        return 'The secret value is already in the clipboard. Reveal it in the terminal too.'
    }

    return 'Show the plain-text secret value in the terminal.'
}

function Get-GerberSecretHidePreviewText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$ClipboardResult
    )

    if ($ClipboardResult.Success) {
        return 'Keep the secret hidden in the terminal. The clipboard already contains the secret value.'
    }

    return 'Keep the secret hidden and return to the secrets menu.'
}

function Get-GerberSecretClipboardStatusMessage {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$ClipboardResult
    )

    if ($ClipboardResult.Success) {
        return 'Gerber already copied the secret value to the clipboard.'
    }

    return $ClipboardResult.Message
}

function ConvertTo-GerberSecretText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return ''
    }

    if ($Value -is [string]) {
        return $Value
    }

    if ($Value -is [securestring]) {
        return ConvertFrom-GerberSecureStringToPlainText -Value $Value
    }

    throw [System.ArgumentException]::new('Gerber can only reveal secrets stored as text.')
}

function ConvertFrom-GerberSecureStringToPlainText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [securestring]$Value
    )

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Get-GerberSecretDisplayText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Value
    )

    if ([string]::IsNullOrEmpty($Value)) {
        return '(empty string)'
    }

    return $Value
}

function Get-GerberSecretsNextCommand {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$ActionTable
    )

    if (Test-GerberSecretsStickyAction -Action $Action -ActionTable $ActionTable) {
        return [pscustomobject]@{
            Arguments = @($Action)
        }
    }

    return [pscustomobject]@{
        Arguments = @()
    }
}

function Test-GerberSecretsStickyAction {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$ActionTable
    )

    if (-not $ActionTable.Contains($Action)) {
        return $false
    }

    return $Action -ne 'list'
}
