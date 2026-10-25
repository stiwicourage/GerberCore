function Resolve-GerberCredentialIdentifier {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Identifier
    )

    if ([string]::IsNullOrWhiteSpace($Identifier)) {
        throw [System.ArgumentException]::new('Gerber credential identifiers must not be empty.')
    }

    $normalizedIdentifier = $Identifier.Trim().ToLowerInvariant()
    if (-not $normalizedIdentifier.StartsWith('gerber:', [System.StringComparison]::Ordinal)) {
        throw [System.ArgumentException]::new("Gerber credential identifiers must start with 'gerber:'.")
    }

    if ($normalizedIdentifier -notmatch '^gerber:[^:]+:[^:]+(?:[^:]|:[^:]+)*$') {
        throw [System.ArgumentException]::new('Gerber credential identifiers must contain a scope and credential name.')
    }

    if ($normalizedIdentifier -notmatch '^gerber:(?:[a-z0-9._%~-]+:)+[a-z0-9._%~-]+$') {
        throw [System.ArgumentException]::new('Gerber credential identifiers contain unsupported characters.')
    }

    return $normalizedIdentifier
}
