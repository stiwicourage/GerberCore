function Get-GerberWithheldRootList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Source,

        [string]$WithoutOwner
    )

    $property = $Source.PSObject.Properties['WithheldRootList']
    if ($null -eq $property) {
        return @()
    }
    $entryList = @(
        foreach ($entry in $property.Value) {
            [pscustomobject]@{ Root = $entry.Root; OwnerNameList = @($entry.OwnerNameList | Where-Object { $_ -ine $WithoutOwner }) }
        }
    )
    return @($entryList | Where-Object { $_.OwnerNameList.Count -ge 2 })
}
