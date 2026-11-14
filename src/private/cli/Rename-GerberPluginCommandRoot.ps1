function Rename-GerberPluginCommandRoot {
    [OutputType([object[]])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$CommandDefinitionList,

        [Parameter(Mandatory)]
        [string]$Alias,

        [Parameter(Mandatory)]
        [string]$PluginName
    )

    $rootList = @($CommandDefinitionList | ForEach-Object { ([string]$_.Name).Trim().Split(' ')[0] } | Select-Object -Unique)
    if ($rootList.Count -ne 1) {
        Write-Warning "Gerber ignored the namespace alias '$Alias' for plugin '$PluginName' because the plugin registers more than one root command."
        return $CommandDefinitionList
    }

    $segmentLength = $rootList[0].Length
    foreach ($definition in $CommandDefinitionList) {
        $renamed = $definition.PSObject.Copy()
        $renamed.Name = $Alias + ([string]$definition.Name).Trim().Substring($segmentLength)
        $renamed
    }
}
