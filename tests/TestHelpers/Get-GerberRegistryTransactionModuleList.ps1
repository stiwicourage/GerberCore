function Get-GerberRegistryTransactionModuleList {
    param(
        [string]$StartPath
    )

    $fixturePath = Get-GerberPluginFixtureModulePath -StartPath $StartPath
    $module = Get-GerberPluginManifestMetadataList -PluginModulePathList @($fixturePath) |
        Where-Object Name -EQ 'Gerber.TestPlugin'
    $module.Name = 'Gerber.A'
    $otherModule = $module.PSObject.Copy()
    $otherModule.Name = 'Gerber.B'
    $otherModule.Guid = 'ba17d0cb-cfea-4cb8-8fcb-fb0d27e8d3a5'
    return @($module, $otherModule)
}
