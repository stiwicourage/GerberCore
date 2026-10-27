function Resolve-GerberCoreUpdatePolicy {
    param([object]$Configuration)
    if ($null -eq $Configuration) { $Configuration = Get-GerberUserConfiguration }
    $null = Test-GerberCoreUpdateConfiguration $Configuration (Resolve-GerberUserConfigPath)
    $channel = 'Stable'
    $section = Get-GerberUserConfigurationPropertyValue $Configuration 'coreUpdates'
    if ($null -ne $section) {
        $value = Get-GerberUserConfigurationPropertyValue $section 'channel'
        if ($null -ne $value) { $channel = $value }
    }
    @{
        Channel = $channel; Scope = 'CurrentUser'
        ExpectedRepositoryUri = [uri]'https://www.powershellgallery.com/api/v2'
    }
}
