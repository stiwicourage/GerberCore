@{
    RootModule = 'Gerber.TerminalFixture.psm1'
    ModuleVersion = '1.0.0'
    GUID = '7dd21b37-e080-4240-b05f-ec727389035e'
    Author = 'Copilot'
    CompanyName = 'Gerber'
    Description = 'Synthetic Gerber terminal regression fixture plugin.'
    PrivateData = @{
        Gerber = @{
            Plugin = $true
            ApiVersion = '1'
            MinimumGerberVersion = '0.1.0-preview'
        }
    }
    FunctionsToExport = @('Get-GerberPlugin')
}
