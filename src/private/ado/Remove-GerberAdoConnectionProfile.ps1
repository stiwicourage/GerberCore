function Remove-GerberAdoConnectionProfile {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $configuration = Get-GerberUserConfiguration
    $connectionProfile = Get-GerberAdoConnectionProfile -Name $Name -Configuration $configuration
    if ($null -eq $connectionProfile) {
        throw [System.ArgumentException]::new("Gerber Azure DevOps profile '$Name' was not found.")
    }

    $candidateConfiguration = Copy-GerberUserConfigurationMap -Configuration $configuration
    $adoConfiguration = Get-GerberOrAddConfigurationSection -Configuration $candidateConfiguration -PropertyName 'ado'
    $profileTable = Get-GerberOrAddConfigurationSection -Configuration $adoConfiguration -PropertyName 'profiles'
    $null = $profileTable.Remove($connectionProfile.Name)

    $defaultProfile = Get-GerberUserConfigurationPropertyValue -Configuration $adoConfiguration -PropertyName 'defaultProfile'
    if (($defaultProfile -is [string]) -and $defaultProfile.Equals($connectionProfile.Name, [System.StringComparison]::OrdinalIgnoreCase)) {
        $null = $adoConfiguration.Remove('defaultProfile')
    }

    $null = Test-GerberUserConfiguration -Configuration $candidateConfiguration -Path (Resolve-GerberUserConfigPath)
    if ($PSCmdlet.ShouldProcess($connectionProfile.Name, 'Remove Gerber Azure DevOps profile')) {
        Save-GerberUserConfiguration -Configuration $candidateConfiguration
    }
}
