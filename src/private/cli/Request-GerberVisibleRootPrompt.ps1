function Request-GerberVisibleRootPrompt {
    [CmdletBinding()]
    param()

    $script:GerberPendingRootPromptBuffer = '/'
    Write-GerberPromptTrace -EventName 'root-prompt-request' -Data @{
        Buffer = $script:GerberPendingRootPromptBuffer
    }
}
