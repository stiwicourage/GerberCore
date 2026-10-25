function Show-GerberAdoAgentReport {
    [CmdletBinding()]
    param()

    $report = Get-GerberAdoAgentReport
    $styleTable = Get-GerberAdoVersionStyleTable -VersionList $report.VersionList

    Start-GerberScreen -Name '/list ado-agents'
    Write-GerberScreenLine -Text '/list ado-agents'
    Write-GerberScreenLine
    foreach ($section in @($report.Sections)) {
        Write-GerberAdoAgentSection -Section $section -StyleTable $styleTable
    }

    Write-GerberAdoVersionLegend -VersionList $report.VersionList -StyleTable $styleTable
}

function Write-GerberAdoAgentSection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Section,

        [Parameter(Mandatory)]
        [hashtable]$StyleTable
    )

    Write-GerberAdoColorLine -Text "=== $(Get-GerberAdoSectionHeading -Section $Section) ===" -ForegroundColor Yellow
    Write-GerberAdoColorLine -Text (Get-GerberAdoAgentHeaderLine) -ForegroundColor Yellow
    if (@($Section.PoolList).Count -eq 0) {
        Write-GerberAdoColorLine -Text "No pools found for poolType=$($Section.PoolType)" -ForegroundColor DarkYellow
        Write-GerberScreenLine
        return
    }

    foreach ($pool in @($Section.PoolList)) {
        Write-GerberScreenLine
        Write-GerberAdoColorLine -Text "Pool: $($pool.Name)" -ForegroundColor Cyan
        if (@($pool.AgentList).Count -eq 0) {
            Write-GerberAdoColorLine -Text '  (No agents in this pool)' -ForegroundColor DarkYellow
            continue
        }

        foreach ($agent in @($pool.AgentList)) {
            Write-GerberAdoAgentRow -Agent $agent -PoolName $pool.Name -StyleTable $StyleTable
        }
    }

    Write-GerberScreenLine
}

function Write-GerberAdoVersionLegend {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$VersionList,

        [Parameter(Mandatory)]
        [hashtable]$StyleTable
    )

    Write-GerberAdoColorLine -Text '=== Version colors ===' -ForegroundColor Yellow
    if ($VersionList.Count -eq 0) {
        Write-GerberAdoColorLine -Text 'No version data was found.' -ForegroundColor DarkYellow
        return
    }

    foreach ($version in $VersionList) {
        Write-GerberAdoStyledText -Text (Get-GerberAdoPaddedText -Text $version -Width 14) -Style $StyleTable[$version]
        $Host.UI.WriteLine()
    }
}

function Get-GerberAdoSectionHeading {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Section
    )

    return '{0} AGENTS ({1} pools)' -f $Section.Name, $Section.PoolType
}

function Get-GerberAdoAgentHeaderLine {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    return '{0,-35}{1,-14}{2,-10}{3}' -f 'Agent Name', 'Version', 'Status', 'Pool'
}

function Write-GerberAdoAgentRow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Agent,

        [Parameter(Mandatory)]
        [string]$PoolName,

        [Parameter(Mandatory)]
        [hashtable]$StyleTable
    )

    $version = Get-GerberAdoVersionDisplayText -Version $Agent.Version
    $status = Get-GerberAdoStatusDisplayText -Status $Agent.Status
    $statusStyle = Get-GerberAdoStatusStyle -Status $status
    $defaultStyle = Get-GerberAdoDefaultStyle

    Write-GerberAdoStyledText -Text (Get-GerberAdoPaddedText -Text $Agent.Name -Width 35) -Style $defaultStyle
    Write-GerberAdoStyledText -Text (Get-GerberAdoPaddedText -Text $version -Width 14) -Style $StyleTable[$Agent.Version]
    Write-GerberAdoStyledText -Text (Get-GerberAdoPaddedText -Text $status -Width 10) -Style $statusStyle
    Write-GerberAdoStyledText -Text $PoolName -Style $defaultStyle
    $Host.UI.WriteLine()
}

function Write-GerberAdoColorLine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory)]
        [System.ConsoleColor]$ForegroundColor
    )

    $promptColors = Get-GerberPromptColorPair
    $style = ConvertTo-GerberPromptLineStyle `
        -ForegroundColor $ForegroundColor `
        -BackgroundColor $promptColors.BackgroundColor
    Write-GerberAdoStyledText -Text $Text -Style $style
    $Host.UI.WriteLine()
}

function Get-GerberAdoDefaultStyle {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param()

    $promptColors = Get-GerberPromptColorPair
    return ConvertTo-GerberPromptLineStyle `
        -ForegroundColor ([System.ConsoleColor]::Gray) `
        -BackgroundColor $promptColors.BackgroundColor
}

function Get-GerberAdoStatusStyle {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Status
    )

    $promptColors = Get-GerberPromptColorPair
    $foregroundColor = if ($Status -eq 'Online') {
        [System.ConsoleColor]::Green
    } else {
        [System.ConsoleColor]::Red
    }

    return ConvertTo-GerberPromptLineStyle `
        -ForegroundColor $foregroundColor `
        -BackgroundColor $promptColors.BackgroundColor
}

function Get-GerberAdoVersionDisplayText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Version
    )

    if ([string]::IsNullOrWhiteSpace($Version) -or ($Version -eq 'unknown')) {
        return ''
    }

    return $Version
}

function Get-GerberAdoStatusDisplayText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Status
    )

    if ($Status -eq 'online') {
        return 'Online'
    }

    if ($Status -eq 'offline') {
        return 'Offline'
    }

    return 'Offline'
}

function Get-GerberAdoPaddedText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory)]
        [int]$Width
    )

    $resolvedText = if ([string]::IsNullOrEmpty($Text)) { '' } else { $Text }
    return $resolvedText.PadRight($Width)
}

function Get-GerberAdoVersionStyleTable {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$VersionList
    )

    $backgroundColor = (Get-GerberPromptColorPair).BackgroundColor
    $colorList = @(Get-GerberAdoVersionColorList -BackgroundColor $backgroundColor)
    $styleTable = @{}
    for ($index = 0; $index -lt $VersionList.Count; $index++) {
        $styleTable[$VersionList[$index]] = ConvertTo-GerberPromptLineStyle `
            -ForegroundColor $colorList[$index % $colorList.Count] `
            -BackgroundColor $backgroundColor
    }

    return $styleTable
}

function Get-GerberAdoVersionColorList {
    [OutputType([System.ConsoleColor[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.ConsoleColor]$BackgroundColor
    )

    $palette = @(
        [System.ConsoleColor]::Cyan
        [System.ConsoleColor]::Green
        [System.ConsoleColor]::Yellow
        [System.ConsoleColor]::Magenta
        [System.ConsoleColor]::Blue
        [System.ConsoleColor]::White
        [System.ConsoleColor]::Red
        [System.ConsoleColor]::DarkCyan
        [System.ConsoleColor]::DarkYellow
        [System.ConsoleColor]::Gray
    )
    $filteredPalette = @($palette | Where-Object { $_ -ne $BackgroundColor })
    if ($filteredPalette.Count -gt 0) {
        return [System.ConsoleColor[]]$filteredPalette
    }

    return [System.ConsoleColor[]]@([System.ConsoleColor]::Cyan)
}

function Write-GerberAdoStyledText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory)]
        [pscustomobject]$Style
    )

    Write-GerberStyledPromptText -Text $Text -Style $Style
}
