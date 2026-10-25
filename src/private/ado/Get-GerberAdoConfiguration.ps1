function Get-GerberAdoConfiguration {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName = 'Selection')]
        [string]$ProfileName,

        [Parameter(Mandatory, ParameterSetName = 'ConnectionProfile')]
        [pscustomobject]$ConnectionProfile,

        [string]$CommandLabel = 'the requested Azure DevOps operation'
    )

    $propertiesData = Get-GerberPropertiesData
    if (($propertiesData -isnot [hashtable]) -or (-not $propertiesData.ContainsKey('ado'))) {
        throw [System.ArgumentException]::new("Gerber could not find Azure DevOps defaults in '$(Get-GerberPropertiesPath)'.")
    }

    $adoData = $propertiesData['ado']
    if ($adoData -isnot [hashtable]) {
        throw [System.ArgumentException]::new("Gerber could not find Azure DevOps defaults in '$(Get-GerberPropertiesPath)'.")
    }

    $resolvedConnectionProfile = if ($PSCmdlet.ParameterSetName -eq 'ConnectionProfile') {
        $ConnectionProfile
    } elseif ($PSBoundParameters.ContainsKey('ProfileName')) {
        (Resolve-GerberAdoConnectionReadiness -ProfileName $ProfileName -CommandLabel $CommandLabel).ConnectionProfile
    } else {
        (Resolve-GerberAdoConnectionReadiness -CommandLabel $CommandLabel).ConnectionProfile
    }
    $defaultApiVersion = Get-GerberAdoRequiredSettingValue -AdoData $adoData -PropertyName 'defaultApiVersion'
    $poolApiVersion = Get-GerberAdoRequiredSettingValue -AdoData $adoData -PropertyName 'poolApiVersion'
    $policyEvaluationApiVersion = Get-GerberAdoRequiredSettingValue -AdoData $adoData -PropertyName 'policyEvaluationApiVersion'
    $collectionName = Get-GerberAdoProfileCollectionName -ConnectionProfile $resolvedConnectionProfile
    $collectionUri = Get-GerberAdoCollectionUri -ConnectionProfile $resolvedConnectionProfile
    $credentialIdentifier = Get-GerberAdoCredentialIdentifier -ProfileName $resolvedConnectionProfile.ProfileName

    return [pscustomobject]@{
        ProfileName                = $resolvedConnectionProfile.ProfileName
        DeploymentType             = $resolvedConnectionProfile.DeploymentType
        ServerUrl                  = $resolvedConnectionProfile.ServerUri
        ServerUri                  = $resolvedConnectionProfile.ServerUri
        Organization               = $resolvedConnectionProfile.Organization
        Collection                 = $resolvedConnectionProfile.Collection
        CollectionName             = $collectionName
        CollectionUri              = $collectionUri
        ProjectName                = $resolvedConnectionProfile.Project
        ProjectUri                 = $resolvedConnectionProfile.ProjectUri
        DefaultApiVersion          = $defaultApiVersion
        PoolApiVersion             = $poolApiVersion
        PolicyEvaluationApiVersion = $policyEvaluationApiVersion
        CredentialIdentifier       = $credentialIdentifier
    }
}

function Get-GerberAdoRequiredSettingValue {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$AdoData,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    $value = [string]$AdoData[$PropertyName]
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw [System.ArgumentException]::new(
            "Gerber found incomplete Azure DevOps defaults in '$(Get-GerberPropertiesPath)'. Missing '$PropertyName'."
        )
    }

    return $value.Trim()
}

function Get-GerberAdoProfileCollectionName {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$ConnectionProfile
    )

    if ($ConnectionProfile.DeploymentType -eq 'Services') {
        return $ConnectionProfile.Organization
    }

    return $ConnectionProfile.Collection
}

function Get-GerberAdoCollectionUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$ConnectionProfile
    )

    $collectionName = Get-GerberAdoProfileCollectionName -ConnectionProfile $ConnectionProfile
    $trimmedCollectionName = $collectionName.Trim().Trim('/')
    return [System.Uri]::new($ConnectionProfile.ServerUri, "$trimmedCollectionName/")
}
