function Show-GerberUpdateMenu {
    param([pscustomobject]$Command)
    if (Test-GerberUpdateInteractive) {
        Show-GerberRegisteredSubcommandMenu -CommandName update -Command $Command -AutoSelectFirstSuggestionOnSubmit
        return
    }
    if ($Command.Arguments.Count -eq 0) {
        Write-GerberScreenLine -Text 'Use /update list to check Core updates, or /update policy in an interactive session to choose the channel.'
        return
    }
    $definition = Get-GerberRegisteredCommand -Name "update $($Command.Arguments[0])"
    $null = Invoke-GerberRegisteredCommand -CommandDefinition $definition -Command $Command
}
