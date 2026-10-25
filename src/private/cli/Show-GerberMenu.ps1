function Show-GerberMenu {
    [CmdletBinding()]
    param()

    Write-GerberMenuEscapeSequenceReset
    while ($true) {
        Start-GerberScreen -Name 'root'
        Show-GerberHomeScreen
        try {
            $shouldExit = Invoke-GerberMenuLoopIteration -ActionList (Get-GerberActionList)
        } catch {
            if (Resolve-GerberMenuLoopException -ErrorRecord $_) {
                continue
            }
            throw
        }

        if ($shouldExit) {
            return
        }
    }
}

function Get-GerberActionList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param()

    $actionList = @(
        foreach ($commandDefinition in (Get-GerberCommandRegistry)) {
            if (-not $commandDefinition.ParentName) {
                $commandDefinition.Name
            }
        }
    )

    return @(Get-GerberRootCommandNameList -ValueList $actionList)
}

function Show-GerberHomeScreen {
    [CmdletBinding()]
    param()

    Write-GerberScreenLine -Text "Gerber - DevOps Multitool"
    Show-GerberStartupUpdateNotification
    Write-GerberScreenLine
}

function Get-GerberRootPromptContext {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param()

    $emptyStateHintText = '/ commands ' + [string][char]0x00B7 + ' esc back'
    return ConvertTo-GerberCommandPromptContext `
        -InitialBuffer (Get-GerberPendingRootPromptBuffer) `
        -EmptyStateHintText $emptyStateHintText
}

function Get-GerberPendingRootPromptBuffer {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    $pendingRootPromptVariable = Get-Variable `
        -Name 'GerberPendingRootPromptBuffer' `
        -Scope Script `
        -ErrorAction SilentlyContinue
    if ($null -eq $pendingRootPromptVariable -or [string]::IsNullOrEmpty($pendingRootPromptVariable.Value)) {
        return ''
    }

    $pendingBuffer = $pendingRootPromptVariable.Value
    $script:GerberPendingRootPromptBuffer = ''
    Write-GerberPromptTrace -EventName 'root-prompt-restore' -Data @{
        Buffer = $pendingBuffer
    }
    return $pendingBuffer
}

function Show-GerberMenuError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Show-GerberTextBlock -Title 'Error' -Text $Message
    try {
        Wait-GerberContinue
    } catch {
        if (-not (Test-GerberMenuEscapeException -Exception $_.Exception)) {
            throw
        }
    }
}

function Get-GerberMenuDisplayException {
    [OutputType([System.Exception])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Exception]$Exception
    )

    $current = $Exception
    while (($null -ne $current.InnerException) -and (Test-GerberWrappedMenuException -Exception $current)) {
        $current = $current.InnerException
    }

    return $current
}

function Test-GerberWrappedMenuException {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Exception]$Exception
    )

    return ($Exception -is [System.Management.Automation.MethodInvocationException]) -or
        ($Exception -is [System.Reflection.TargetInvocationException]) -or
        ($Exception -is [System.Management.Automation.RuntimeException])
}

function Test-GerberMenuStopException {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Exception]$Exception
    )

    if ($Exception -is [System.Management.Automation.PipelineStoppedException]) {
        return $true
    }

    return $Exception -is [System.OperationCanceledException]
}

function Format-GerberMenuRecoverableError {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Exception]$Exception
    )

    $detailMessage = Get-GerberMenuErrorDetail -Exception $Exception
    if ([string]::IsNullOrWhiteSpace($detailMessage)) {
        return 'Gerber could not complete that action.'
    }

    return @(
        'Gerber could not complete that action.'
        ''
        $detailMessage
    ) -join [Environment]::NewLine
}

function Get-GerberMenuErrorDetail {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Exception]$Exception
    )

    if ($Exception -is [System.UnauthorizedAccessException]) {
        return Format-GerberAccessDeniedMessage -Message $Exception.Message
    }

    return $Exception.Message
}

function Format-GerberAccessDeniedMessage {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $path = Get-GerberQuotedPath -Message $Message
    if ([string]::IsNullOrWhiteSpace($path)) {
        return 'Access was denied. Check file or directory permissions and try again.'
    }

    return "Access to '$path' was denied. Check file or directory permissions and try again."
}

function Get-GerberQuotedPath {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $pathMatch = [regex]::Match($Message, "'([^']+)'")
    if (-not $pathMatch.Success) {
        return $null
    }

    return $pathMatch.Groups[1].Value
}

function Invoke-GerberMenuCommand {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Command
    )

    $commandDefinition = Get-GerberRegisteredCommand -Name $Command.Name
    if ($null -eq $commandDefinition) {
        throw [System.ArgumentException]::new("Unknown Gerber root command '$($Command.Name)'.")
    }

    return Invoke-GerberRegisteredCommand -CommandDefinition $commandDefinition -Command $Command
}
