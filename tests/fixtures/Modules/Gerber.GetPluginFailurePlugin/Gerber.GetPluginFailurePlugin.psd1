@{
    RootModule        = 'Gerber.GetPluginFailurePlugin.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'c6080be8-7dd3-43f5-b086-c389e7b3461c'
    PowerShellVersion = '7.4'
    FunctionsToExport = @(
        'Get-GerberPlugin'
    )
    PrivateData       = @{
        Gerber = @{
            Plugin               = $true
            ApiVersion           = '1'
            MinimumGerberVersion = '0.1.0-preview'
        }
    }
}
