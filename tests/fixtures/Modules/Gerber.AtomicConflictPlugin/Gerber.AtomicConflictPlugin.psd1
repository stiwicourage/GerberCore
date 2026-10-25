@{
    RootModule        = 'Gerber.AtomicConflictPlugin.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '2382ed8c-4c3e-4e86-9019-6f6b49c7bfe5'
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
