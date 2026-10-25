@{
    RootModule        = 'Gerber.UnsupportedApiPlugin.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '08e53288-7e2a-47a7-bd70-cb96db66467b'
    PowerShellVersion = '7.4'
    FunctionsToExport = @('Get-GerberPlugin')
    PrivateData       = @{
        Gerber = @{
            Plugin               = $true
            ApiVersion           = '2'
            MinimumGerberVersion = '0.1.0-preview'
        }
    }
}
