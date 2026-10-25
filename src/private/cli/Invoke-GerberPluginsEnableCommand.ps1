function Invoke-GerberPluginsEnableCommand {
    [CmdletBinding()]
    param(
        [pscustomobject]$Command = [pscustomobject]@{ Arguments = @() }
    )

    Assert-GerberPluginsActivationCommandInput -Command $Command -CommandName 'enable'
    $inactivePluginList = @(
        Get-GerberPluginInventory | Where-Object { $_.IsDiscovered -and (-not $_.Loaded) }
    )
    $plugin = Read-GerberPluginSelection `
        -CommandTitle '/plugins enable' `
        -EmptyText 'No installed Gerber plugins are available to enable.' `
        -PluginList $inactivePluginList
    if ($null -eq $plugin) {
        return
    }

    $null = Enable-GerberPlugin -Guid $plugin.Guid
    Show-GerberTextBlock `
        -Title '/plugins enable' `
        -Text "Enabled and approved plugin '$($plugin.DisplayName)'. Its commands are available now."
    Wait-GerberContinue
}
