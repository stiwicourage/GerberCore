function Get-GerberAdoBuildTagSet {
    [OutputType([System.Collections.Generic.HashSet[string]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [int]$BuildId
    )

    $tagSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($tag in @(Get-GerberAdoBuildTagList `
                -Configuration $Configuration `
                -Pat $Pat `
                -BuildId $BuildId)) {
        if ([string]::IsNullOrWhiteSpace([string]$tag)) {
            continue
        }

        $null = $tagSet.Add([string]$tag)
    }

    Write-Output -InputObject $tagSet -NoEnumerate
}
