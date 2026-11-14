function Get-GerberPluginNamespaceAlias {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [hashtable]$Configuration,

        [Parameter(Mandatory)]
        [string]$Guid
    )

    if ($null -eq $Configuration) {
        $Configuration = Get-GerberUserConfiguration
    }

    $pluginConfiguration = Get-GerberUserConfigurationPropertyValue -Configuration $Configuration -PropertyName 'plugins'
    if ($null -eq $pluginConfiguration) {
        return $null
    }
    $aliasTable = Get-GerberUserConfigurationPropertyValue -Configuration $pluginConfiguration -PropertyName 'aliases'
    if ($null -eq $aliasTable) {
        return $null
    }

    return [string](Get-GerberUserConfigurationPropertyValue -Configuration $aliasTable -PropertyName $Guid.ToLowerInvariant())
}
