function Copy-GerberCommandRegistryState {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param([Parameter(Mandatory)][pscustomobject]$State)

    $memo = [System.Collections.Generic.Dictionary[object, object]]::new([System.Collections.Generic.ReferenceEqualityComparer]::Instance)
    return [pscustomobject][ordered]@{
        CommandList = @(foreach ($command in $State.CommandList) {
            Copy-GerberCommandRegistryValue -Value $command -Memo $memo
        })
        PluginList = @($State.PluginList)
        GerberVersion = $State.GerberVersion
    }
}
