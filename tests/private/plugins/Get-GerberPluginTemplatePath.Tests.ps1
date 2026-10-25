BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberPluginTemplatePath' -Tag 'PluginCreate' {
    It 'finds the Gerber-owned template sources' {
        Test-Path (Join-Path (Get-GerberPluginTemplatePath) 'src/public/Get-GerberPlugin.ps1.template') | Should -BeTrue
    }

    It 'explains how to recover from missing templates' {
        Mock Test-Path { $false }
        { Get-GerberPluginTemplatePath } | Should -Throw '*Rebuild or reinstall Gerber*'
    }
}
