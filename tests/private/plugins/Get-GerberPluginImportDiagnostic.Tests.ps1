BeforeAll {
    . (Join-Path $PSScriptRoot '../../../src/private/plugins/Get-GerberPluginImportDiagnostic.ps1')
    . (Join-Path $PSScriptRoot '../../../src/private/plugins/Get-GerberBoundaryDiagnostic.ps1')
    . (Join-Path $PSScriptRoot '../../../src/private/plugins/Resolve-GerberStaticSourceValue.ps1')
}

Describe 'Get-GerberPluginImportDiagnostic' -Tag 'PluginBoundary' {
    It 'allows ordinary module inspection without entering Core scope' {
        $tree = [System.Management.Automation.Language.Parser]::ParseInput('Get-Module Gerber', [ref]$null, [ref]$null)
        $diagnostics = @(Get-GerberPluginImportDiagnostic -Command $tree.EndBlock.Statements[0].PipelineElements[0] `
            -Document @{ File = 'src/Own.ps1' } -Name 'Get-Module')
        $diagnostics.Count | Should -Be 0
    }

    It 'does not confuse a module object argument with module-scope invocation' {
        $tree = [System.Management.Automation.Language.Parser]::ParseInput('& Write-Output (Get-Module Gerber)', [ref]$null, [ref]$null)
        $command = @($tree.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true))[1]
        $diagnostics = @(Get-GerberPluginImportDiagnostic -Command $command `
            -Document @{ File = 'src/Own.ps1' } -Name 'Get-Module')
        $diagnostics.Count | Should -Be 0
    }
}
