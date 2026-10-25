function ConvertTo-GerberBase64 {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Value
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    return [Convert]::ToBase64String($bytes)
}
