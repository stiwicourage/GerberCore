function Get-GerberPluginCredentialIdentifier {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [guid]$PluginId,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$PathSegmentList
    )

    if ($PathSegmentList.Count -eq 0) {
        throw [System.ArgumentException]::new(
            'Gerber plugin API secret operations require at least one path segment.'
        )
    }

    return Get-GerberCredentialIdentifier `
        -Scope 'plugin' `
        -SegmentList (@($PluginId.ToString('D')) + $PathSegmentList)
}
