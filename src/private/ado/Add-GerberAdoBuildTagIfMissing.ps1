function Add-GerberAdoBuildTagIfMissing {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [int]$BuildId,

        [Parameter(Mandatory)]
        [string]$Tag
    )

    $normalizedTag = ConvertTo-GerberAdoBuildTagText -Tag $Tag
    if ([string]::IsNullOrWhiteSpace($normalizedTag)) {
        return $false
    }

    $tagSet = Get-GerberAdoBuildTagSet `
        -Configuration $Configuration `
        -Pat $Pat `
        -BuildId $BuildId
    if ($null -eq $tagSet) {
        $tagSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    }

    if ($tagSet.Contains($normalizedTag)) {
        return $false
    }

    Add-GerberAdoBuildTag `
        -Configuration $Configuration `
        -Pat $Pat `
        -BuildId $BuildId `
        -Tag $normalizedTag
    return $true
}
