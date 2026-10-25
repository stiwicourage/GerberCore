function Get-GerberAdoApiUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$BaseUri,

        [Parameter(Mandatory)]
        [hashtable]$QueryParameterMap
    )

    $queryValueList = @(
        foreach ($name in $QueryParameterMap.Keys) {
            '{0}={1}' -f [uri]::EscapeDataString($name), [uri]::EscapeDataString([string]$QueryParameterMap[$name])
        }
    )

    $uriBuilder = [System.UriBuilder]::new($BaseUri)
    $uriBuilder.Query = $queryValueList -join '&'
    return $uriBuilder.Uri
}
