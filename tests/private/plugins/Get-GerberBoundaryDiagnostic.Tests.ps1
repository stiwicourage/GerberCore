BeforeAll {
    . (Join-Path $PSScriptRoot '../../../src/private/plugins/Get-GerberBoundaryDiagnostic.ps1')
}

Describe 'Get-GerberBoundaryDiagnostic' -Tag 'PluginBoundary' {
    It 'preserves the exact source location and actionable finding fields' {
        $tree = [System.Management.Automation.Language.Parser]::ParseInput("`n  Test-Example", [ref]$null, [ref]$null)
        $record = Get-GerberBoundaryDiagnostic -Document @{ File = 'src/Example.ps1' } `
            -Extent $tree.EndBlock.Statements[0].Extent `
            -Finding @{ Dependency = 'Test-Example'; Reason = 'PrivateCoreCommand'; Resolution = 'Use public API.' }
        $record.File | Should -Be 'src/Example.ps1'
        $record.Line | Should -Be 2
        $record.Column | Should -Be 3
        $record.Dependency | Should -Be 'Test-Example'
        $record.Resolution | Should -Be 'Use public API.'
    }
}
