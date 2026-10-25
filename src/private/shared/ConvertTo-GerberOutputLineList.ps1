function ConvertTo-GerberOutputLineList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object[]]$Output
    )

    return @(
        foreach ($item in @($Output)) {
            if ($null -ne $item) {
                [string]$item
            }
        }
    )
}
