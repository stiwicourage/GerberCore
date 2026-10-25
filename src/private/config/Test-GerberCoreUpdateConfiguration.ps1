function Test-GerberCoreUpdateConfiguration {
    param([object]$Configuration, [string]$Path)
    if (-not (Test-GerberCoreUpdatePropertyPresent $Configuration 'coreUpdates')) { return $true }
    $section = $Configuration.coreUpdates
    if (-not (Test-GerberUserConfigurationRootObject $section)) {
        throw [System.IO.InvalidDataException]::new("Gerber user configuration file '$Path' property 'coreUpdates' must be a JSON object.")
    }
    if (Test-GerberCoreUpdatePropertyPresent $section 'channel') { Assert-GerberCoreUpdateChannel $section.channel $Path }
    $true
}

function Assert-GerberCoreUpdateChannel {
    param([object]$Channel, [string]$Path)
    if ($Channel -isnot [string] -or $Channel -cnotin @('Stable', 'IncludePrerelease')) {
        throw [System.IO.InvalidDataException]::new("Gerber user configuration file '$Path' property 'coreUpdates.channel' must be 'Stable' or 'IncludePrerelease'.")
    }
}

function Test-GerberCoreUpdatePropertyPresent {
    param([object]$Configuration, [string]$Name)
    if ($Configuration -is [System.Collections.IDictionary]) { return $Configuration.Contains($Name) }
    $null -ne $Configuration.PSObject.Properties[$Name]
}
