function Get-GerberPromptLineStyle {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Line
    )

    if (-not $Line.IsSelected) {
        return $null
    }

    return Resolve-GerberSelectedPromptLineStyle
}

function Resolve-GerberSelectedPromptLineStyle {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param()

    $promptColors = Get-GerberPromptColorPair
    if ($null -eq $promptColors) {
        return Resolve-GerberFallbackPromptLineStyle
    }

    if (-not (Test-GerberPromptColorPairKnown -PromptColorPair $promptColors)) {
        return Resolve-GerberFallbackPromptLineStyle
    }

    $derivedStyle = Resolve-GerberDerivedPromptLineStyle -ForegroundColor $promptColors.ForegroundColor -BackgroundColor $promptColors.BackgroundColor
    if ($null -ne $derivedStyle) {
        return $derivedStyle
    }

    return ConvertTo-GerberPromptLineStyle -ForegroundColor $promptColors.BackgroundColor -BackgroundColor $promptColors.ForegroundColor
}

function Resolve-GerberFallbackPromptLineStyle {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param()

    if (-not (Test-GerberVirtualTerminalPromptStylingAvailable)) {
        return $null
    }

    return Get-GerberReversePromptLineStyle
}

function Test-GerberPromptColorPairKnown {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PromptColorPair
    )

    return (Test-GerberKnownConsoleColor -Color $PromptColorPair.ForegroundColor) -and
        (Test-GerberKnownConsoleColor -Color $PromptColorPair.BackgroundColor)
}

function Test-GerberKnownConsoleColor {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.ConsoleColor]$Color
    )

    return [System.Enum]::IsDefined([System.ConsoleColor], $Color)
}

function Get-GerberPromptColorPair {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param()

    return [pscustomobject]@{
        ForegroundColor = $Host.UI.RawUI.ForegroundColor
        BackgroundColor = $Host.UI.RawUI.BackgroundColor
    }
}

function Resolve-GerberDerivedPromptLineStyle {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.ConsoleColor]$ForegroundColor,

        [Parameter(Mandatory)]
        [System.ConsoleColor]$BackgroundColor
    )

    $bestStyle = $null
    $bestScore = 0.0
    foreach ($highlightBackgroundColor in [System.Enum]::GetValues([System.ConsoleColor])) {
        $styleCandidate = Resolve-GerberPromptStyleCandidate -HighlightBackgroundColor $highlightBackgroundColor -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
        if (($null -eq $styleCandidate) -or ($styleCandidate.Score -le $bestScore)) {
            continue
        }

        $bestStyle = $styleCandidate.Style
        $bestScore = $styleCandidate.Score
    }

    return $bestStyle
}

function Resolve-GerberPromptStyleCandidate {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.ConsoleColor]$HighlightBackgroundColor,

        [Parameter(Mandatory)]
        [System.ConsoleColor]$ForegroundColor,

        [Parameter(Mandatory)]
        [System.ConsoleColor]$BackgroundColor
    )

    if (($HighlightBackgroundColor -eq $ForegroundColor) -or ($HighlightBackgroundColor -eq $BackgroundColor)) {
        return $null
    }

    foreach ($highlightForegroundColor in @($ForegroundColor, $BackgroundColor)) {
        $styleScore = Get-GerberPromptStyleScore -HighlightForegroundColor $highlightForegroundColor -HighlightBackgroundColor $HighlightBackgroundColor -BackgroundColor $BackgroundColor
        if ($styleScore -le 0) {
            continue
        }

        return [pscustomobject]@{
            Style = ConvertTo-GerberPromptLineStyle -ForegroundColor $highlightForegroundColor -BackgroundColor $HighlightBackgroundColor
            Score = $styleScore
        }
    }

    return $null
}

function Get-GerberPromptStyleScore {
    [OutputType([double])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.ConsoleColor]$HighlightForegroundColor,

        [Parameter(Mandatory)]
        [System.ConsoleColor]$HighlightBackgroundColor,

        [Parameter(Mandatory)]
        [System.ConsoleColor]$BackgroundColor
    )

    if ($HighlightForegroundColor -eq $HighlightBackgroundColor) {
        return [double]0
    }

    $textContrast = Get-GerberColorContrastRatio -FirstColor $HighlightForegroundColor -SecondColor $HighlightBackgroundColor
    $rowContrast = Get-GerberColorContrastRatio -FirstColor $HighlightBackgroundColor -SecondColor $BackgroundColor
    if (($textContrast -lt 4.5) -or ($rowContrast -lt 1.5)) {
        return [double]0
    }

    return [Math]::Min($textContrast, $rowContrast)
}

function ConvertTo-GerberPromptLineStyle {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.ConsoleColor]$ForegroundColor,

        [Parameter(Mandatory)]
        [System.ConsoleColor]$BackgroundColor
    )

    return [pscustomobject]@{
        Mode = 'ColorPair'
        ForegroundColor = $ForegroundColor
        BackgroundColor = $BackgroundColor
    }
}

function Get-GerberReversePromptLineStyle {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param()

    return [pscustomobject]@{
        Mode = 'ReverseVideo'
        ForegroundColor = $null
        BackgroundColor = $null
    }
}

function Get-GerberColorContrastRatio {
    [OutputType([double])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.ConsoleColor]$FirstColor,

        [Parameter(Mandatory)]
        [System.ConsoleColor]$SecondColor
    )

    $firstLuminance = Get-GerberColorLuminance -Color $FirstColor
    $secondLuminance = Get-GerberColorLuminance -Color $SecondColor
    $lighterColor = [Math]::Max($firstLuminance, $secondLuminance)
    $darkerColor = [Math]::Min($firstLuminance, $secondLuminance)
    return ($lighterColor + 0.05) / ($darkerColor + 0.05)
}

function Get-GerberColorLuminance {
    [OutputType([double])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.ConsoleColor]$Color
    )

    $colorMap = Get-GerberConsoleColorMap
    $rgbColor = $colorMap[$Color.ToString()]
    $redChannel = ConvertTo-GerberLinearColorChannel -Value ($rgbColor['Red'] / 255)
    $greenChannel = ConvertTo-GerberLinearColorChannel -Value ($rgbColor['Green'] / 255)
    $blueChannel = ConvertTo-GerberLinearColorChannel -Value ($rgbColor['Blue'] / 255)
    return (0.2126 * $redChannel) + (0.7152 * $greenChannel) + (0.0722 * $blueChannel)
}

function ConvertTo-GerberLinearColorChannel {
    [OutputType([double])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [double]$Value
    )

    if ($Value -le 0.03928) {
        return $Value / 12.92
    }

    return [Math]::Pow(($Value + 0.055) / 1.055, 2.4)
}

function Get-GerberConsoleColorMap {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param()

    return @{
        Black = @{ Red = 0; Green = 0; Blue = 0 }
        DarkBlue = @{ Red = 0; Green = 0; Blue = 128 }
        DarkGreen = @{ Red = 0; Green = 100; Blue = 0 }
        DarkCyan = @{ Red = 0; Green = 139; Blue = 139 }
        DarkRed = @{ Red = 139; Green = 0; Blue = 0 }
        DarkMagenta = @{ Red = 139; Green = 0; Blue = 139 }
        DarkYellow = @{ Red = 184; Green = 134; Blue = 11 }
        Gray = @{ Red = 190; Green = 190; Blue = 190 }
        DarkGray = @{ Red = 105; Green = 105; Blue = 105 }
        Blue = @{ Red = 30; Green = 144; Blue = 255 }
        Green = @{ Red = 0; Green = 255; Blue = 0 }
        Cyan = @{ Red = 0; Green = 255; Blue = 255 }
        Red = @{ Red = 255; Green = 69; Blue = 58 }
        Magenta = @{ Red = 255; Green = 0; Blue = 255 }
        Yellow = @{ Red = 255; Green = 255; Blue = 0 }
        White = @{ Red = 255; Green = 255; Blue = 255 }
    }
}

function Write-GerberStyledPromptText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory)]
        [pscustomobject]$Style
    )

    if (Test-GerberVirtualTerminalPromptStylingAvailable) {
        Write-GerberAnsiStyledPromptText -Text $Text -Style $Style
        return
    }

    Write-GerberRawUiStyledPromptText -Text $Text -Style $Style
}

function Test-GerberVirtualTerminalPromptStylingAvailable {
    [OutputType([bool])]
    [CmdletBinding()]
    param()

    return $Host.UI.SupportsVirtualTerminal
}

function Write-GerberAnsiStyledPromptText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory)]
        [pscustomobject]$Style
    )

    $escapeCharacter = [char]27
    if ($Style.Mode -eq 'ReverseVideo') {
        $Host.UI.Write(('{0}[7m{1}{0}[0m' -f $escapeCharacter, $Text))
        return
    }

    $foregroundCode = Get-GerberConsoleColorAnsiCode -Color $Style.ForegroundColor -Kind 'Foreground'
    $backgroundCode = Get-GerberConsoleColorAnsiCode -Color $Style.BackgroundColor -Kind 'Background'
    $styledText = '{0}[{1};{2}m{3}{0}[0m' -f $escapeCharacter, $foregroundCode, $backgroundCode, $Text
    $Host.UI.Write($styledText)
}

function Get-GerberConsoleColorAnsiCode {
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.ConsoleColor]$Color,

        [ValidateSet('Foreground', 'Background')]
        [string]$Kind
    )

    $baseCode = switch ($Color) {
        ([System.ConsoleColor]::Black) { 30 }
        ([System.ConsoleColor]::DarkRed) { 31 }
        ([System.ConsoleColor]::DarkGreen) { 32 }
        ([System.ConsoleColor]::DarkYellow) { 33 }
        ([System.ConsoleColor]::DarkBlue) { 34 }
        ([System.ConsoleColor]::DarkMagenta) { 35 }
        ([System.ConsoleColor]::DarkCyan) { 36 }
        ([System.ConsoleColor]::Gray) { 37 }
        ([System.ConsoleColor]::DarkGray) { 90 }
        ([System.ConsoleColor]::Red) { 91 }
        ([System.ConsoleColor]::Green) { 92 }
        ([System.ConsoleColor]::Yellow) { 93 }
        ([System.ConsoleColor]::Blue) { 94 }
        ([System.ConsoleColor]::Magenta) { 95 }
        ([System.ConsoleColor]::Cyan) { 96 }
        ([System.ConsoleColor]::White) { 97 }
    }

    if ($Kind -eq 'Foreground') {
        return $baseCode
    }

    return $baseCode + 10
}

function Write-GerberRawUiStyledPromptText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory)]
        [pscustomobject]$Style
    )

    $rawUi = $Host.UI.RawUI
    $originalForegroundColor = $rawUi.ForegroundColor
    $originalBackgroundColor = $rawUi.BackgroundColor
    try {
        $rawUi.ForegroundColor = $Style.ForegroundColor
        $rawUi.BackgroundColor = $Style.BackgroundColor
        $Host.UI.Write($Text)
    } finally {
        $rawUi.ForegroundColor = $originalForegroundColor
        $rawUi.BackgroundColor = $originalBackgroundColor
    }
}
