function Get-GerberRegistryTransactionSnapshot {
    param()

    return ([ordered]@{
        Commands = @(Get-GerberCommandRegistry | Select-Object Name, Description, OwnerName, OwnerType, ParentName, LeafName, Subcommands,
            @{ Name = 'Handler'; Expression = { $_.Handler.ToString() } })
        Plugins = @($script:GerberCommandRegistryState.PluginList | Select-Object Name, Guid)
        Catalog = Get-GerberCommandCatalog -ActionList (Get-GerberActionList)
        Suggestions = @(Get-GerberActionList)
    } | ConvertTo-Json -Depth 100 -Compress)
}
