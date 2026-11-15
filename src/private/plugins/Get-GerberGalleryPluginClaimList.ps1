function Get-GerberGalleryPluginClaimList {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $candidate = @(Find-PSResource -Name $Name -Repository PSGallery -ErrorAction Stop) | Select-Object -First 1
    if ($null -eq $candidate) {
        throw "Module '$Name' was not found on PowerShell Gallery."
    }

    $namespace = Get-GerberGalleryNamespaceFromTagList -TagList $candidate.Tags
    if ([string]::IsNullOrEmpty($namespace)) {
        return [pscustomobject]@{ Namespace = $null; ClaimList = @() }
    }

    $claimNameList = @(Find-PSResource -Tag "GerberNamespace_$namespace" -Repository PSGallery -ErrorAction Stop).Name
    $versionList = foreach ($claimName in ($claimNameList + $Name | Select-Object -Unique)) {
        Find-PSResource -Name $claimName -Version '*' -Repository PSGallery -ErrorAction Stop
    }
    return [pscustomobject]@{
        Namespace = $namespace
        ClaimList = @(ConvertTo-GerberGalleryPluginClaimList -ResourceList @($versionList) -Namespace $namespace)
    }
}
