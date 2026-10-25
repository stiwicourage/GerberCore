function Set-GerberAdoDefaultConnectionProfile {
    [OutputType([pscustomobject])]
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
    $adoConfiguration['defaultProfile'] = $connectionProfile.Name
    $null = Test-GerberUserConfiguration -Configuration $candidateConfiguration -Path (Resolve-GerberUserConfigPath)

    if ($PSCmdlet.ShouldProcess($connectionProfile.Name, 'Set Gerber default Azure DevOps profile')) {
        Save-GerberUserConfiguration -Configuration $candidateConfiguration
    }

    return Get-GerberAdoConnectionProfile -Name $connectionProfile.Name -Configuration $candidateConfiguration
}
