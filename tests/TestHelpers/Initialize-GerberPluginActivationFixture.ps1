$script:testPluginGuid = '6996218c-58d0-48ce-b6cc-38d06149230a'
$script:secondPluginGuid = 'ba17d0cb-cfea-4cb8-8fcb-fb0d27e8d3a5'
$script:failingPluginGuid = 'fef6be2a-a261-4d7f-a7d8-c8a6c9e9fd39'

function Initialize-GerberPluginActivationFixture {
    param(
        [string]$StartPath,
        [string]$TestDrivePath
    )

    Reset-GerberPluginTestEnvironment
    $fixture = Get-GerberPluginActivationFixturePathSet -StartPath $StartPath -TestDrivePath $TestDrivePath
    $fixture | Add-Member -NotePropertyName OriginalConfigPath -NotePropertyValue $env:GERBER_CONFIG_PATH
    $env:GERBER_CONFIG_PATH = $fixture.ConfigPath
    $null = Initialize-GerberCommandRegistry -PluginModulePathList @()
    return $fixture
}

function Get-GerberPluginActivationFixturePathSet {
    param(
        [string]$StartPath,
        [string]$TestDrivePath
    )

    $moduleRoot = New-GerberPluginFixtureModuleRoot `
        -StartPath $StartPath `
        -ModuleNameList @('Gerber.TestPlugin', 'Gerber.SecondTestPlugin', 'Gerber.ImportFailurePlugin')
    return [pscustomobject]@{
        ModuleRoot = $moduleRoot
        ConfigPath = Join-Path $TestDrivePath ([guid]::NewGuid().ToString() + '/config.json')
    }
}
