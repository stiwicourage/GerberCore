function Invoke-GerberPluginsDisableCommand {
    [CmdletBinding()]
    param(
        [pscustomobject]$Command = [pscustomobject]@{ Arguments = @() }
    )

    Assert-GerberPluginsActivationCommandInput -Command $Command -CommandName 'disable'
    $activePluginList = @(Get-GerberPluginInventory | Where-Object { $_.Loaded })
    $plugin = Read-GerberPluginSelection `
        -CommandTitle '/plugins disable' `
        -EmptyText 'No enabled Gerber plugins are available to disable.' `
        -PluginList $activePluginList
    if ($null -eq $plugin) {
        return
    }

    Disable-GerberPlugin -Guid $plugin.Guid
    Show-GerberTextBlock `
        -Title '/plugins disable' `
        -Text "Disabled plugin '$($plugin.DisplayName)'. Its approval is preserved and its commands are removed."
    Wait-GerberContinue
}
