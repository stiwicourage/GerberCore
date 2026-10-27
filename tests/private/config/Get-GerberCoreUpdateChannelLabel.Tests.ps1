BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    . "$root/src/private/config/Get-GerberCoreUpdateChannelLabel.ps1"
    . "$root/src/private/update/Format-GerberCoreUpdateOverview.ps1"
}

Describe 'Get-GerberCoreUpdateChannelLabel' -Tag 'CoreUpdatePolicy' {
    Context 'human-readable policy in discovery and confirmation' {
        It 'shows the selected <channel> without exposing PMU identifiers in the channel line' -ForEach @(
            @{ channel = 'Stable'; label = 'Stable only' }
            @{ channel = 'IncludePrerelease'; label = 'Include prereleases' }
        ) {
            $state = [pscustomobject]@{
                Name = 'Gerber'; Installed = '0.1.0'; Available = '0.2.0'
                Repository = 'PSGallery'; Status = 'Available'; Channel = $channel
            }
            (Format-GerberCoreUpdateOverview $state) | Should -Match ([regex]::Escape("Channel: $label."))
        }
    }
}
