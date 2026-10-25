function Get-GerberCredentialIdentifier {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Scope,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$SegmentList
    )

    $normalizedScope = ConvertTo-GerberCredentialIdentifierSegment -Value $Scope -Label 'credential scope'
    $normalizedSegmentList = @(
        foreach ($segment in $SegmentList) {
            ConvertTo-GerberCredentialIdentifierSegment -Value $segment -Label 'credential path segments'
        }
    )
    if ($normalizedSegmentList.Count -eq 0) {
        throw [System.ArgumentException]::new('Gerber credential path segments must not be empty.')
    }

    return Resolve-GerberCredentialIdentifier -Identifier (
        'gerber:{0}:{1}' -f $normalizedScope, ($normalizedSegmentList -join ':')
    )
}

function ConvertTo-GerberCredentialIdentifierSegment {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory)]
        [string]$Label
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw [System.ArgumentException]::new("Gerber $Label must not be empty.")
    }

    return [uri]::EscapeDataString($Value.Trim().ToLowerInvariant())
}
