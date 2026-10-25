@{
    RootModule        = 'Gerber.IncompatibleVersionPlugin.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '2f0df22a-7a54-4b3a-b0b0-a9d7f97cfd2b'
    PowerShellVersion = '7.4'
    FunctionsToExport = @('Get-GerberPlugin')
    PrivateData       = @{
        Gerber = @{
            Plugin               = $true
            ApiVersion           = '1'
            MinimumGerberVersion = '9.0.0'
        }
    }
}
