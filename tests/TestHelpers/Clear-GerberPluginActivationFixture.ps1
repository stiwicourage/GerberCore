function Clear-GerberPluginActivationFixture {
    param(
        [pscustomobject]$Fixture
    )

    Reset-GerberPluginTestEnvironment
    Remove-GerberPluginFixtureModuleRoot -Path $Fixture.ModuleRoot
    $env:GERBER_CONFIG_PATH = $Fixture.OriginalConfigPath
    $null = Initialize-GerberCommandRegistry -PluginModulePathList @()
}
