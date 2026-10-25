function ConvertFrom-GerberBase64 {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Value
    )

    $normalizedValue = ($Value.Trim() -replace '\s+', '')
    if ([string]::IsNullOrWhiteSpace($normalizedValue)) {
        throw [System.ArgumentException]::new('Enter a Base64 value to decode.')
    }

    try {
        $bytes = [Convert]::FromBase64String($normalizedValue)
    } catch [System.FormatException] {
        throw [System.ArgumentException]::new('That value is not valid Base64. Remove extra characters and try again.')
    }

    $encoding = [System.Text.UTF8Encoding]::new($false, $true)
    try {
        return $encoding.GetString($bytes)
    } catch [System.Text.DecoderFallbackException] {
        throw [System.ArgumentException]::new('That Base64 value does not decode to UTF-8 text.')
    }
}
