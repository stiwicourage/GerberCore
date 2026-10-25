function Get-GerberAlphabeticallySortedStringList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [System.Collections.IEnumerable]$ValueList
    )

    $stringList = [System.Collections.Generic.List[string]]::new()
    foreach ($value in @($ValueList)) {
        if ($null -ne $value) {
            $null = $stringList.Add([string]$value)
        }
    }

    $stringList.Sort([System.Comparison[string]]{
            param($Left, $Right)

            $primaryComparison = [System.StringComparer]::OrdinalIgnoreCase.Compare($Left, $Right)
            if ($primaryComparison -ne 0) {
                return $primaryComparison
            }

            return [System.StringComparer]::Ordinal.Compare($Left, $Right)
        })
    return [string[]]$stringList
}
