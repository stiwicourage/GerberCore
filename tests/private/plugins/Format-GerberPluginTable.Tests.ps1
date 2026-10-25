BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Format-GerberPluginTable' {
    It 'renders a fixed-width table with headers and unavailable values' {
        $table = Format-GerberPluginTable `
            -ColumnList @(
                @{ Header = 'Name'; PropertyName = 'Name' }
                @{ Header = 'State'; PropertyName = 'State' }
            ) `
            -RowList @(
                [pscustomobject]@{ Name = 'Gerber.TestPlugin'; State = 'Enabled' }
                [pscustomobject]@{ Name = $null; State = 'Missing' }
            )

        $table | Should -Match 'Name'
        $table | Should -Match 'State'
        $table | Should -Match 'Gerber.TestPlugin'
        $table | Should -Match 'Enabled'
        $table | Should -Match ([regex]::Escape([string][char]0x2014))
        $table | Should -Match ([regex]::Escape([string][char]0x2500))
    }
}
