function Get-GerberCoreUpdateChannelLabel {
    param([ValidateSet('Stable', 'IncludePrerelease')][string]$Channel)
    $labels = @{ Stable = 'Stable only'; IncludePrerelease = 'Include prereleases' }
    $labels[$Channel]
}
