@{
    RootModule        = 'Gerber.ConflictCorePlugin.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'de84b0ab-ea6c-4cb8-b7bf-0e4881719a2b'
    PowerShellVersion = '7.4'
    FunctionsToExport = @('Get-GerberPlugin')
    PrivateData       = @{
        Gerber = @{
            Plugin               = $true
            ApiVersion           = '1'
            MinimumGerberVersion = '0.1.0-preview'
        }
    }
}
