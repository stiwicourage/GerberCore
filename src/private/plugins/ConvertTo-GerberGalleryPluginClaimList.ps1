function ConvertTo-GerberGalleryPluginClaimList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$ResourceList,

        [Parameter(Mandatory)]
        [string]$Namespace
    )

    return @(
        foreach ($group in (@($ResourceList) | Group-Object Name)) {
            # The Gallery exposes no module GUID in search results, so the module name is the claim identity.
            [pscustomobject]@{
                Guid           = [string]$group.Name
                Name           = [string]$group.Name
                Namespace      = $Namespace
                FirstPublished = ($group.Group | Measure-Object -Property PublishedDate -Minimum).Minimum
            }
        }
    )
}
