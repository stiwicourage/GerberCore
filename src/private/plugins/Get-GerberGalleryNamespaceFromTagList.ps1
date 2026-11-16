function Get-GerberGalleryNamespaceFromTagList {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$TagList
    )

    $namespaceTag = @($TagList) | Where-Object { $_ -like 'GerberNamespace_*' } | Select-Object -First 1
    if ($null -eq $namespaceTag) {
        return $null
    }

    return $namespaceTag.Substring('GerberNamespace_'.Length)
}
