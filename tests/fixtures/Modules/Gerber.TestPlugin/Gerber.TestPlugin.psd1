@{
    RootModule        = 'Gerber.TestPlugin.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '6996218c-58d0-48ce-b6cc-38d06149230a'
    PowerShellVersion = '7.4'
    FunctionsToExport = @(
        'Get-GerberPlugin',
        'Get-GerberTestPluginHandlerContext',
        'Get-GerberTestPluginInvocationCount',
        'Get-GerberTestPluginRegistrationContext',
        'Reset-GerberTestPluginInvocationCount'
    )
    PrivateData       = @{
        Gerber = @{
            Plugin               = $true
            ApiVersion           = '1'
            MinimumGerberVersion = '0.1.0-preview'
        }
    }
}
