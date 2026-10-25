@{
    RootModule        = 'Gerber.ConflictOnePlugin.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '4b4dc2a4-6d50-4697-b2ff-3629f8231bb5'
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
