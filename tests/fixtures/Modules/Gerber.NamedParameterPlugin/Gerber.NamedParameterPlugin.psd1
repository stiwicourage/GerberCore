@{
    RootModule        = 'Gerber.NamedParameterPlugin.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '8df96b7f-f0c0-4658-b9b0-716a46bc8874'
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
