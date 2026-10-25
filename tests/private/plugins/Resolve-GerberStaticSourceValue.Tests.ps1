BeforeAll {
    . (Join-Path $PSScriptRoot '../../../src/private/plugins/Resolve-GerberStaticSourceValue.ps1')
}

Describe 'Resolve-GerberStaticSourceValue' -Tag 'PluginBoundary' {
    It 'resolves <Source> conservatively' -ForEach @(
        @{ Source = "'literal'"; Expected = 'literal' }
        @{ Source = "('left' + 'right')"; Expected = 'leftright' }
        @{ Source = '(Get-Content ./unknown)'; Expected = $null }
        @{ Source = '$unknown'; Expected = $null }
        @{ Source = "('first' | Write-Output)"; Expected = $null }
        @{ Source = '42'; Expected = $null }
    ) {
        $tree = [System.Management.Automation.Language.Parser]::ParseInput("& $Source", [ref]$null, [ref]$null)
        $command = $tree.EndBlock.Statements[0].PipelineElements[0]
        Resolve-GerberStaticSourceValue -Node $command.CommandElements[0] | Should -Be $Expected
    }
}
