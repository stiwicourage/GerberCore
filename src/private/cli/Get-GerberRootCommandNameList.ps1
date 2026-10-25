function Get-GerberRootCommandNameList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [System.Collections.IEnumerable]$ValueList
    )

    $reservedNameList = @('exit', 'help', 'plugins', 'update')
    $sortedNameList = @(Get-GerberAlphabeticallySortedStringList -ValueList $ValueList)
    $reservedMatchList = @(
        foreach ($reservedName in $reservedNameList) {
            $sortedNameList | Where-Object { $_ -ieq $reservedName }
        }
    )
    $remainingNameList = @($sortedNameList | Where-Object { $reservedNameList -notcontains $_ })

    return [string[]]@($reservedMatchList + $remainingNameList)
}
