function Wait-GerberContinue {
    [CmdletBinding()]
    param()

    Clear-GerberPendingConsoleInput
    if (-not (Test-GerberInteractivePromptAvailable)) {
        Read-Host -Prompt 'Press Enter to continue' | Out-Null
        return
    }

    Wait-GerberInteractiveContinue
}

function Wait-GerberInteractiveContinue {
    [CmdletBinding()]
    param()

    Write-GerberContinuePrompt
    while ($true) {
        $key = Read-GerberContinueKey
        if ($key.Key -eq [System.ConsoleKey]::Escape) {
            throw (Get-GerberMenuEscapeException)
        }

        if ($key.Key -eq [System.ConsoleKey]::Enter) {
            break
        }
    }

    $Host.UI.WriteLine()
}

function Write-GerberContinuePrompt {
    [CmdletBinding()]
    param()

    $Host.UI.Write('Press Enter to continue: ')
}

function Read-GerberContinueKey {
    [OutputType([System.ConsoleKeyInfo])]
    [CmdletBinding()]
    param()

    return Read-GerberMenuConsoleKey
}
