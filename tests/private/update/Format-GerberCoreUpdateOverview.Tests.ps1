BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    . "$root/src/private/update/Format-GerberCoreUpdateOverview.ps1"
}

Describe 'Format-GerberCoreUpdateOverview' -Tag 'G4A7' {
    Context 'shared summary and confirmation table' {
        It 'does not invent a channel when configuration discovery failed before policy resolution' {
            $state = [pscustomobject]@{
                Name = 'Gerber'; Installed = '0.1.0'; Available = '-'
                Repository = 'PSGallery'; Status = 'Unavailable'; Channel = $null
            }
            $text = Format-GerberCoreUpdateOverview $state
            $text | Should -Match 'Unavailable'
            $text | Should -Not -Match 'Channel:|Stable only'
        }
        It 'formats only public overview fields rather than plans or credentials' {
            $text = Format-GerberCoreUpdateOverview -State ([pscustomobject]@{
                Name = 'Gerber'; Installed = '0.1.0'; Available = '0.2.0'; Repository = 'Feed'; Status = 'Available'
                Plan = 'private-plan'; Credential = 'private-credential'
            })
            $text | Should -Match 'Installed.*Available.*Repository'
            $text | Should -Match 'Core.*Gerber.*0.1.0.*0.2.0.*Feed'
            $text | Should -Not -Match 'private-plan|private-credential'
        }
    }
}
