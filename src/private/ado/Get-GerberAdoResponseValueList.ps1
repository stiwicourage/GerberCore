function Get-GerberAdoResponseValueList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Response
    )

    if ($null -eq $Response) {
        return @()
    }

    if (($Response -is [hashtable]) -and $Response.ContainsKey('value')) {
        return @($Response.value)
    }

    if ($Response.PSObject.Properties.Match('value').Count -eq 0) {
        return @()
    }

    return @($Response.value)
}
