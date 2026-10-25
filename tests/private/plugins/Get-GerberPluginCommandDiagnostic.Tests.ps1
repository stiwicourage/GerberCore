BeforeAll {
    . (Join-Path $PSScriptRoot '../../../src/private/plugins/Get-GerberPluginCommandDiagnostic.ps1')
    . (Join-Path $PSScriptRoot '../../../src/private/plugins/Get-GerberBoundaryDiagnostic.ps1')
    . (Join-Path $PSScriptRoot '../../../src/private/plugins/Resolve-GerberStaticSourceValue.ps1')
    . (Join-Path $PSScriptRoot '../../../src/private/plugins/Get-GerberPluginImportDiagnostic.ps1')
}

Describe 'Get-GerberPluginCommandDiagnostic' -Tag 'PluginBoundary' {
    It 'does not treat another module qualification as Core ownership' {
        $tree = [System.Management.Automation.Language.Parser]::ParseInput('OtherModule\Private-Example', [ref]$null, [ref]$null)
        $contract = [pscustomobject]@{ PrivateCommands = @{ 'Private-Example' = 'Use public API.' } }
        $diagnostics = @(Get-GerberPluginCommandDiagnostic -Command $tree.EndBlock.Statements[0].PipelineElements[0] `
            -Document @{ File = 'src/Own.ps1' } -Contract $contract -OwnedNames @())
        $diagnostics.Count | Should -Be 0
    }
}
