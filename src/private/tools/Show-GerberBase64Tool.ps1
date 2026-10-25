function Show-GerberBase64Tool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Command
    )

    $actionTable = Get-GerberBase64ActionTable
    $currentCommand = $Command
    while ($true) {
        $action = Read-GerberBase64Action -Command $currentCommand -ActionTable $actionTable
        if ([string]::IsNullOrWhiteSpace($action)) {
            return
        }

        $currentCommand = Invoke-GerberBase64ActionFlow -Action $action -ActionTable $actionTable
    }
}

function Read-GerberBase64Action {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Command,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$ActionTable
    )

    try {
        return Get-GerberMenuSubcommand -CommandName 'tools base-64' -Command $Command -SubcommandTable $ActionTable
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) {
            return ''
        }

        throw
    }
}

function Invoke-GerberBase64ActionFlow {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$ActionTable
    )

    try {
        $result = Invoke-GerberBase64Action -Action $Action
        Show-GerberBase64Result -Action $Action -Result $result
        return Complete-GerberActionContinue -Action $Action -ActionTable $ActionTable
    } catch [System.ArgumentException] {
        Show-GerberTextBlock -Title 'Error' -Text $_.Exception.Message
        return Complete-GerberActionContinue -Action $Action -ActionTable $ActionTable
    } catch {
        if (-not (Test-GerberMenuEscapeException -Exception $_.Exception)) {
            throw
        }

        return ConvertTo-GerberNestedCommand
    }
}

function Complete-GerberActionContinue {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$ActionTable
    )

    try {
        Wait-GerberContinue
        return Get-GerberBase64NextCommand -Action $Action -ActionTable $ActionTable
    } catch {
        if (-not (Test-GerberMenuEscapeException -Exception $_.Exception)) {
            throw
        }

        return ConvertTo-GerberNestedCommand
    }
}

function Get-GerberBase64ActionTable {
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    [CmdletBinding()]
    param()

    return [ordered]@{
        encode = 'Encode UTF-8 text as Base64'
        decode = 'Decode Base64 text into UTF-8 text'
    }
}

function Invoke-GerberBase64Action {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Action
    )

    switch ($Action) {
        'encode' {
            Show-GerberBase64ActionScreen -Action $Action
            return Invoke-GerberBase64Encode
        }
        'decode' {
            Show-GerberBase64ActionScreen -Action $Action
            return Invoke-GerberBase64Decode
        }
        default {
            throw [System.ArgumentException]::new("Unknown Base64 action '$Action'. Use encode or decode.")
        }
    }
}

function Invoke-GerberBase64Encode {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param()

    $value = Read-GerberCommand -Prompt 'Text to encode' -SuggestionMode 'None' -TrimResult $false
    $convertedValue = ConvertTo-GerberBase64 -Value $value
    return ConvertTo-GerberBase64ToolResult -Value $convertedValue -ClipboardResult (Copy-GerberValueToClipboard -Value $convertedValue)
}

function Invoke-GerberBase64Decode {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param()

    $value = Read-GerberCommand -Prompt 'Base64 to decode' -SuggestionMode 'None' -TrimResult $false
    $convertedValue = ConvertFrom-GerberBase64 -Value $value
    return ConvertTo-GerberBase64ToolResult -Value $convertedValue -ClipboardResult (Copy-GerberValueToClipboard -Value $convertedValue)
}

function ConvertTo-GerberBase64ToolResult {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory)]
        [pscustomobject]$ClipboardResult
    )

    return [pscustomobject]@{
        Value = $Value
        ClipboardResult = $ClipboardResult
    }
}

function Get-GerberBase64NextCommand {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$ActionTable
    )

    if ($ActionTable.Contains($Action)) {
        return [pscustomobject]@{
            Arguments = @($Action)
        }
    }

    return [pscustomobject]@{
        Arguments = @()
    }
}

function Show-GerberBase64ActionScreen {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Action
    )

    Start-GerberScreen -Name "/tools base-64 $Action"
    Write-GerberScreenLine -Text "/tools base-64 $Action"
    Write-GerberScreenLine
}
