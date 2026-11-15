function Test-GerberPluginNamespaceRegistryClaim {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Guid,

        [Parameter(Mandatory)]
        [string]$Namespace,

        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$ClaimList,

        [string]$LookupFailure
    )

    if (-not [string]::IsNullOrWhiteSpace($LookupFailure)) {
        return Get-GerberPluginNamespaceClaimResult -Status 'Unverified' -Reason $LookupFailure
    }

    $owner = Get-GerberPluginNamespaceClaimOwner -Namespace $Namespace -ClaimList @($ClaimList)
    if ($null -eq $owner) {
        return Get-GerberPluginNamespaceClaimResult -Status 'Available'
    }

    $status = if ($owner.Guid -ieq $Guid) { 'Owner' } else { 'Conflict' }
    return Get-GerberPluginNamespaceClaimResult -Status $status -Owner $owner
}

function Get-GerberPluginNamespaceClaimOwner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Namespace,

        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$ClaimList
    )

    # The earliest first publication wins; the GUID makes ties independent of list order.
    return @($ClaimList | Where-Object { $_.Namespace -ieq $Namespace } |
            Sort-Object -Property @{ Expression = { $_.FirstPublished } }, @{ Expression = { $_.Guid.ToLowerInvariant() } })[0]
}

function Get-GerberPluginNamespaceClaimResult {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Status,

        [AllowNull()]
        [object]$Owner,

        [string]$Reason
    )

    return [pscustomobject]@{ Status = $Status; Owner = $Owner; Reason = $Reason }
}
