function Show-GerberCreateUuidTool {
    [CmdletBinding()]
    param()

    while ($true) {
        $result = Get-GerberCreateUuidToolResult
        Show-GerberCreateUuidResult -Result $result
        if (-not (Read-GerberCreateUuidRepeatChoice)) {
            return
        }
    }
}

function Get-GerberCreateUuidToolResult {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param()

    $value = Get-GerberUuidValue
    return [pscustomobject]@{
        Value = $value
        ClipboardResult = Copy-GerberValueToClipboard -Value $value
    }
}

function Get-GerberUuidValue {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    return [guid]::NewGuid().ToString()
}

function Show-GerberCreateUuidResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Result
    )

    Show-GerberTextBlock -Title '/tools create-uuid' -Text (Format-GerberCreateUuidResultText -Result $Result)
}

function Format-GerberCreateUuidResultText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Result
    )

    return @(
        'UUID'
        $Result.Value
        ''
        (Get-GerberCreateUuidClipboardMessage -ClipboardResult $Result.ClipboardResult)
    ) -join [Environment]::NewLine
}

function Get-GerberCreateUuidClipboardMessage {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$ClipboardResult
    )

    if ($ClipboardResult.Success) {
        return 'Copied the UUID to the clipboard.'
    }

    return $ClipboardResult.Message
}

function Read-GerberCreateUuidRepeatChoice {
    [OutputType([bool])]
    [CmdletBinding()]
    param()

    Clear-GerberPendingConsoleInput
    if (-not (Test-GerberInteractivePromptAvailable)) {
        return Read-GerberCreateUuidFallbackChoice
    }

    return Read-GerberCreateUuidInteractiveChoice
}

function Read-GerberCreateUuidFallbackChoice {
    [OutputType([bool])]
    [CmdletBinding()]
    param()

    while ($true) {
        $response = Read-Host -Prompt 'Press Enter to generate another, or Esc to go back'
        if ([string]::IsNullOrWhiteSpace($response)) {
            return $true
        }

        if (Test-GerberCreateUuidEscapeText -Text $response) {
            return $false
        }
    }
}

function Read-GerberCreateUuidInteractiveChoice {
    [OutputType([bool])]
    [CmdletBinding()]
    param()

    Write-GerberCreateUuidRepeatPrompt
    while ($true) {
        $key = Read-GerberContinueKey
        if ($key.Key -eq [System.ConsoleKey]::Enter) {
            $Host.UI.WriteLine()
            return $true
        }

        if ($key.Key -eq [System.ConsoleKey]::Escape) {
            $Host.UI.WriteLine()
            return $false
        }
    }
}

function Write-GerberCreateUuidRepeatPrompt {
    [CmdletBinding()]
    param()

    $Host.UI.Write('Press Enter to generate another, or Esc to go back: ')
}

function Test-GerberCreateUuidEscapeText {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    return @('esc', 'escape') -contains $Text.Trim().ToLowerInvariant()
}
