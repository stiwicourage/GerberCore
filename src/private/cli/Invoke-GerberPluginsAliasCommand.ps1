function Invoke-GerberPluginsAliasCommand {
    [CmdletBinding()]
    param(
        [pscustomobject]$Command = [pscustomobject]@{ Arguments = @() }
    )

    Assert-GerberPluginsActivationCommandInput -Command $Command -CommandName 'alias'
    $plugin = Read-GerberPluginSelection `
        -CommandTitle '/plugins alias' `
        -EmptyText 'No Gerber plugins are available to alias.' `
        -PluginList @(Get-GerberPluginInventory)
    if ($null -eq $plugin) {
        return
    }

    $alias = Read-GerberPluginAliasChange -Plugin $plugin
    if ($null -eq $alias) {
        return
    }

    Show-GerberTextBlock -Title '/plugins alias' -Text (Get-GerberPluginAliasResultText -Plugin $plugin -Alias $alias)
    Wait-GerberContinue
}

function Read-GerberPluginAliasChange {
    param([pscustomobject]$Plugin)

    Write-GerberScreenLine -Text "Enter a namespace alias for '$($Plugin.DisplayName)', or press Enter to remove it. Esc goes back."
    while ($true) {
        try {
            $alias = [string](Read-GerberCommand -Prompt 'Namespace alias' -SuggestionMode 'None' -TrimResult $true)
        } catch {
            if (Test-GerberMenuEscapeException -Exception $_.Exception) {
                return $null
            }
            throw
        }

        try {
            Set-GerberPluginNamespaceAlias -Guid $Plugin.Guid -Alias $alias
            return $alias
        } catch [System.ArgumentException] {
            Show-GerberTextBlock -Title '/plugins alias' -Text $_.Exception.Message
        }
    }
}

function Get-GerberPluginAliasResultText {
    param([pscustomobject]$Plugin, [string]$Alias)

    if ([string]::IsNullOrEmpty($Alias)) {
        return "Removed the namespace alias for '$($Plugin.DisplayName)'. Restart Gerber to use its own namespace again."
    }

    return "Plugin '$($Plugin.DisplayName)' will use '/$Alias' as its namespace. Restart Gerber to apply it."
}
