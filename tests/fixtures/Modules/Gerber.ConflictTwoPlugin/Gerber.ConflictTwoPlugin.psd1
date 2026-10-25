@{
    RootModule        = 'Gerber.ConflictTwoPlugin.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '6d28bf95-77d7-4617-a7af-8bb6b073438f'
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
