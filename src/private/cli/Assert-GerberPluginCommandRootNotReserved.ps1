function Assert-GerberPluginCommandRootNotReserved {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$CommandDefinitionList,

        [Parameter(Mandatory)]
        [string]$PluginName
    )

    $reservedRootList = @('exit', 'help', 'plugins', 'update', 'tools', 'secrets')
    foreach ($definition in $CommandDefinitionList) {
        $segmentList = @(([string]$definition.Name).Trim().Split(' '))
        $root = $segmentList[0].ToLowerInvariant()
        # An exact root clash is reported by the existing registry owner-conflict check.
        if ($segmentList.Count -gt 1 -and $reservedRootList -contains $root) {
            throw [System.InvalidOperationException]::new(
                "Gerber plugin '$PluginName' cannot register command '$($definition.Name)' because '$root' is a root reserved for Gerber Core."
            )
        }
    }
}
