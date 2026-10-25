function Publish-GerberCommandRegistryState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$RegistryBuilder
    )

    $script:GerberCommandRegistryState = [pscustomobject][ordered]@{
        CommandList   = $RegistryBuilder.CommandList.ToArray()
        PluginList    = $RegistryBuilder.PluginList.ToArray()
        GerberVersion = $RegistryBuilder.GerberVersion.ToString()
    }
}
