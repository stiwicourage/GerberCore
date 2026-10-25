function Show-GerberTextBlock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    Start-GerberScreen -Name $Title
    Write-GerberScreenLine -Text $Title
    Write-GerberScreenLine
    Write-GerberScreenLine -Text $Text
}
