@{
    RootModule        = 'Gerber.ImportFailurePlugin.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'fef6be2a-a261-4d7f-a7d8-c8a6c9e9fd39'
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
