@{
    RootModule        = 'Gerber.MissingEntryPointPlugin.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '09d440e4-5b4f-4a89-9bb8-f7bdb8d61cb5'
    PowerShellVersion = '7.4'
    FunctionsToExport = @('Get-GerberPluginInfo')
    PrivateData       = @{
        Gerber = @{
            Plugin               = $true
            ApiVersion           = '1'
            MinimumGerberVersion = '0.1.0-preview'
        }
    }
}
