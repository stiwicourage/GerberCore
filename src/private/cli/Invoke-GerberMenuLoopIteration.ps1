function Invoke-GerberMenuLoopIteration {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$ActionList
    )

    $command = Read-GerberMenuLoopCommand -ActionList $ActionList
    if (-not $command.IsValid) {
        Show-GerberTextBlock -Title 'Error' -Text $command.ErrorMessage
        Wait-GerberContinue
        return $false
    }

    return Invoke-GerberMenuCommand -Command $command
}

function Read-GerberMenuLoopCommand {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$ActionList
    )

    return Resolve-GerberCommand `
        -InputText (Read-GerberCommand -Prompt ([char]0x276F) -PromptContext (Get-GerberRootPromptContext)) `
        -ActionList $ActionList
}

function Resolve-GerberMenuLoopException {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ErrorRecord')]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [Parameter(Mandatory, ParameterSetName = 'Exception')]
        [System.Exception]$Exception
    )

    if ($PSCmdlet.ParameterSetName -eq 'ErrorRecord') {
        $Exception = $ErrorRecord.Exception
    }
    Write-GerberMenuLoopExceptionTrace -Exception $Exception -ErrorRecord $ErrorRecord

    if (Test-GerberImmediateMenuException -Exception $Exception) {
        Write-GerberPromptTrace -EventName 'menu-loop-exception-path' -Data @{ Path = 'argument-or-invalid-data' }
        Show-GerberMenuError -Message $Exception.Message
        return $true
    }

    return Resolve-GerberMenuDisplayException -Exception $Exception
}

function Write-GerberMenuLoopExceptionTrace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Exception]$Exception,

        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    Write-GerberPromptTrace -EventName 'menu-loop-exception' -Data @{
        ExceptionType        = $Exception.GetType().FullName
        Message              = $Exception.Message
        FullyQualifiedErrorId = if ($null -eq $ErrorRecord) { '' } else { $ErrorRecord.FullyQualifiedErrorId }
        ScriptStackTrace     = if ($null -eq $ErrorRecord) { '' } else { $ErrorRecord.ScriptStackTrace }
        PositionMessage      = if ($null -eq $ErrorRecord) { '' } else { $ErrorRecord.InvocationInfo.PositionMessage }
    }
}

function Test-GerberImmediateMenuException {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Exception]$Exception
    )

    return ($Exception -is [System.ArgumentException]) -or
        ($Exception -is [System.IO.InvalidDataException])
}

function Resolve-GerberMenuDisplayException {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Exception]$Exception
    )

    $displayException = Get-GerberMenuDisplayException -Exception $Exception
    Write-GerberPromptTrace -EventName 'menu-loop-exception-display' -Data @{
        DisplayExceptionType = $displayException.GetType().FullName
        HasEscapeData        = $displayException.Data.Contains('GerberMenuEscape')
        HasRootData          = $displayException.Data.Contains('GerberRootNavigation')
    }

    if (Test-GerberMenuEscapeException -Exception $displayException) {
        Write-GerberPromptTrace -EventName 'menu-loop-exception-path' -Data @{ Path = 'escape-continue' }
        return $true
    }

    if (Test-GerberRootNavigationException -Exception $displayException) {
        Write-GerberPromptTrace -EventName 'menu-loop-exception-path' -Data @{ Path = 'root-continue' }
        return $true
    }

    if (Test-GerberMenuStopException -Exception $displayException) {
        Write-GerberPromptTrace -EventName 'menu-loop-exception-path' -Data @{ Path = 'stop-exit' }
        return $false
    }

    Write-GerberPromptTrace -EventName 'menu-loop-exception-path' -Data @{ Path = 'recoverable-error' }
    Show-GerberMenuError -Message (Format-GerberMenuRecoverableError -Exception $displayException)
    return $true
}
