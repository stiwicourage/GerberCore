@{
    RootModule        = 'Gerber.SecondTestPlugin.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'ba17d0cb-cfea-4cb8-8fcb-fb0d27e8d3a5'
    PowerShellVersion = '7.4'
    FunctionsToExport = @(
        'Get-GerberPlugin',
        'Get-GerberSecondTestPluginRegistrationContext'
    )
    PrivateData       = @{
        Gerber = @{
            Plugin               = $true
            ApiVersion           = '1'
            MinimumGerberVersion = '0.1.0-preview'
        }
    }
}
