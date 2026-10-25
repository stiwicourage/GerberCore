function Write-GerberScreenLine {
    [CmdletBinding()]
    param(
        [string]$Text = ''
    )

    $Text | Out-Host
}
