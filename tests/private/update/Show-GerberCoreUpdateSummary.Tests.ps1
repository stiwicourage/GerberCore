BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    . "$root/src/private/update/Show-GerberCoreUpdateSummary.ps1"
    . "$root/src/private/update/Format-GerberCoreUpdateOverview.ps1"
    . "$root/src/private/cli/Write-GerberScreenLine.ps1"
}

Describe 'Show-GerberCoreUpdateSummary' -Tag 'G4A7' {
    Context 'compact Core overview' {
        It 'shows component name installed available and exact repository without secret fields' {
            $script:lines = [System.Collections.Generic.List[string]]::new()
            Mock Write-GerberScreenLine { $script:lines.Add($Text) }
            Show-GerberCoreUpdateSummary -State ([pscustomobject]@{
                Name = 'Gerber'; Installed = '0.1.0-preview'; Available = '0.2.0'; Repository = 'TeamFeed'
                Status = 'Available'; Message = 'An update is available.'; Credential = 'private-secret'
            })
            $text = $script:lines -join "`n"
            $text | Should -Match 'Core.*Gerber'
            $text | Should -Match '0.1.0-preview'
            $text | Should -Match '0.2.0'
            $text | Should -Match 'TeamFeed'
            $text | Should -Not -Match 'private-secret'
        }
    }
}
