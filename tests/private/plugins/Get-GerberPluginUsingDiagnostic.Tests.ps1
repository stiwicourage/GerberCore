BeforeAll {
    . (Join-Path $PSScriptRoot '../../../src/private/plugins/Get-GerberPluginUsingDiagnostic.ps1')
    . (Join-Path $PSScriptRoot '../../../src/private/plugins/Get-GerberPluginImportDiagnostic.ps1')
    . (Join-Path $PSScriptRoot '../../../src/private/plugins/Get-GerberBoundaryDiagnostic.ps1')
    . (Join-Path $PSScriptRoot '../../../src/private/plugins/Resolve-GerberStaticSourceValue.ps1')
}

Describe 'Get-GerberPluginUsingDiagnostic' -Tag 'PluginBoundary' {
    It 'ignores using namespace and permits a public manifest import' {
        $tree = [System.Management.Automation.Language.Parser]::ParseInput(
            "using namespace System.Text`nusing module '/modules/Gerber/Gerber.psd1'", [ref]$null, [ref]$null)
        $diagnostics = @(Get-GerberPluginUsingDiagnostic -Document @{ Tree = $tree; File = 'src/Own.ps1' })
        $diagnostics.Count | Should -Be 0
    }
}
