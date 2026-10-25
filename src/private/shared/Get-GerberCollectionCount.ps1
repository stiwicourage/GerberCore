function Get-GerberCollectionCount {
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$InputObject
    )

    if ($null -eq $InputObject) {
        return 0
    }

    if ($InputObject -is [string]) {
        return 1
    }

    if ($InputObject -is [System.Collections.ICollection]) {
        return $InputObject.Count
    }

    return @($InputObject).Count
}
