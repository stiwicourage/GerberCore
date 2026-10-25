function Write-GerberProgressBar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Current,

        [Parameter(Mandatory)]
        [int]$Total,

        [string]$Prefix = '',

        [switch]$OverwritePreviousRender
    )

    $barWidth = 30
    $filledCharacter = [string]([char]0x2588)
    $emptyCharacter = [string]([char]0x2591)
    $ratio = if ($Total -gt 0) { $Current / $Total } else { 0 }
    $filled = [int]([Math]::Round($barWidth * $ratio))
    if ($filled -gt $barWidth) { $filled = $barWidth }
    $bar = ($filledCharacter * $filled) + ($emptyCharacter * ($barWidth - $filled))
    $separator = if ([string]::IsNullOrEmpty($Prefix)) { '' } else { ' ' }
    $moveUp = if ($OverwritePreviousRender -or $Current -gt 1) { "$([char]27)[1A" } else { '' }
    $Host.UI.Write("$moveUp`r$Prefix$separator[$bar]`n")
}
