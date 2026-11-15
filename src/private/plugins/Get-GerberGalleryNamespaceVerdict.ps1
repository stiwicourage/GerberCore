function Get-GerberGalleryNamespaceVerdict {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    try {
        $lookup = Get-GerberGalleryPluginClaimList -Name $Name
    } catch {
        return Get-GerberGalleryNamespaceVerdictRecord -Status 'Unverified' -Reason $_.Exception.Message
    }

    if ([string]::IsNullOrEmpty($lookup.Namespace)) {
        return Get-GerberGalleryNamespaceVerdictRecord -Status 'Unverified' `
            -Reason "Module '$Name' publishes no Gerber namespace tag."
    }

    $claim = Test-GerberPluginNamespaceRegistryClaim -Guid $Name -Namespace $lookup.Namespace -ClaimList $lookup.ClaimList
    return Get-GerberGalleryNamespaceVerdictRecord -Status $claim.Status -Owner $claim.Owner -Namespace $lookup.Namespace
}

function Get-GerberGalleryNamespaceVerdictRecord {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [string]$Status,
        [object]$Owner,
        [string]$Reason,
        [string]$Namespace
    )

    return [pscustomobject]@{ Status = $Status; Owner = $Owner; Reason = $Reason; Namespace = $Namespace }
}
