function Show-GerberBase64Result {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [pscustomobject]$Result
    )

    Show-GerberTextBlock -Title "/tools base-64 $Action" -Text (Format-GerberBase64ResultText -Result $Result)
}

function Format-GerberBase64ResultText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Result
    )

    return @(
        'Result'
        Format-GerberBase64ResultValue -Value $Result.Value
        ''
        $Result.ClipboardResult.Message
    ) -join [Environment]::NewLine
}

function Format-GerberBase64ResultValue {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Value
    )

    if ($Value -eq '') {
        return '(empty string)'
    }

    return $Value
}
