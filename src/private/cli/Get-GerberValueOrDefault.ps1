function Get-GerberValueOrDefault {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [string]$Value,

        [Parameter(Mandatory)]
        [string]$DefaultValue
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $DefaultValue
    }

    return $Value
}
