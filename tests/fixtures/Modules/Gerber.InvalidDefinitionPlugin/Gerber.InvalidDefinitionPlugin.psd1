@{
    RootModule        = 'Gerber.InvalidDefinitionPlugin.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '6ad6d849-7006-4262-bb77-4ff3e0615ccb'
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
