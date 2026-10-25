BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Clear-GerberCommandRegistry' {
    It 'removes the effective session registry until it is initialized again' {
        Clear-GerberCommandRegistry

        {
            Get-GerberCommandRegistry
        } | Should -Throw 'Gerber command registry has not been initialized for this session.'

        Initialize-GerberCommandRegistry -PluginModulePathList @()
        (Get-GerberCommandRegistry).Name | Should -Contain 'tools'
    }
}
