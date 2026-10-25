param(
    [string]$OutputDirectory = './artifacts'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ScriptAnalyzerCIScriptRoot = $PSScriptRoot
$script:RequiredPSScriptAnalyzerVersion = [version]'1.25.0'
$script:ScriptAnalyzerExcludedRules = @('PSAvoidUsingWriteHost')

function Get-ScriptAnalyzerRepositoryRoot {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    return Split-Path -Parent (Split-Path -Parent $script:ScriptAnalyzerCIScriptRoot)
}

function Test-IsGeneratedAnalysisPath {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$RepositoryRoot
    )

    $relativePath = [System.IO.Path]::GetRelativePath(
        [System.IO.Path]::GetFullPath($RepositoryRoot),
        [System.IO.Path]::GetFullPath($Path)
    ).Replace('\', '/')

    return $relativePath -match '(^|.*/)(dist|artifacts)(/|$)'
}

function Get-ScriptAnalyzerInputPathList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$RepositoryRoot
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return [string[]]@()
    }

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        return [string[]]@([System.IO.Path]::GetFullPath($Path))
    }

    return [string[]]@(
        Get-ChildItem -LiteralPath $Path -Recurse -File |
            Where-Object Extension -In @('.ps1', '.psm1', '.psd1') |
            Where-Object { -not (Test-IsGeneratedAnalysisPath -Path $_.FullName -RepositoryRoot $RepositoryRoot) } |
            ForEach-Object FullName
    )
}

function Get-ScriptAnalyzerAnalysisPathList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot
    )

    $analysisPathList = @('src', 'scripts', 'tests', 'run.ps1')

    return [string[]]@(
        foreach ($analysisPath in $analysisPathList) {
            Get-ScriptAnalyzerInputPathList `
                -Path (Join-Path $RepositoryRoot $analysisPath) `
                -RepositoryRoot $RepositoryRoot
        }
    )
}

function Import-ScriptAnalyzerModule {
    [OutputType([version])]
    [CmdletBinding()]
    param()

    try {
        Import-Module PSScriptAnalyzer -ErrorAction Stop
    } catch {
        throw "PSScriptAnalyzer $script:RequiredPSScriptAnalyzerVersion is required but could not be imported. $($_.Exception.Message)"
    }

    $analyzerModule = Get-Module PSScriptAnalyzer
    if ($null -eq $analyzerModule) {
        throw "PSScriptAnalyzer $script:RequiredPSScriptAnalyzerVersion is required but Import-Module did not load the module."
    }

    return [version]$analyzerModule.Version
}

function Confirm-ScriptAnalyzerVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][version]$AnalyzerVersion
    )

    if ($AnalyzerVersion -eq $script:RequiredPSScriptAnalyzerVersion) {
        return
    }

    throw "PSScriptAnalyzer version $AnalyzerVersion is installed, but version $script:RequiredPSScriptAnalyzerVersion is required."
}

function Get-ScriptAnalyzerResultList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$AnalysisPathList
    )

    return [object[]]@(
        foreach ($analysisPath in $AnalysisPathList) {
            Invoke-ScriptAnalyzerWithTransientRetry -Path $analysisPath
        }
    )
}

function Invoke-ScriptAnalyzerWithTransientRetry {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        return @(Invoke-ScriptAnalyzer -Path $Path -ExcludeRule $script:ScriptAnalyzerExcludedRules)
    } catch [System.NullReferenceException] {
        return @(Invoke-ScriptAnalyzer -Path $Path -ExcludeRule $script:ScriptAnalyzerExcludedRules)
    }
}

function ConvertTo-ScriptAnalyzerFindingRecordList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyCollection()]
        [Parameter(Mandatory)][object[]]$ResultList,
        [Parameter(Mandatory)][string]$RepositoryRoot
    )

    $safeResultList = @($ResultList)

    return [object[]]@(
        foreach ($result in $safeResultList) {
            [pscustomobject][ordered]@{
                Severity     = [string]$result.Severity
                RuleName     = [string]$result.RuleName
                RelativePath = [System.IO.Path]::GetRelativePath($RepositoryRoot, $result.ScriptPath).Replace('\', '/')
                Line         = [int]$result.Line
                Message      = [string]$result.Message
            }
        }
    )
}

function Get-ScriptAnalyzerReportSection {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Title,
        [AllowEmptyCollection()]
        [Parameter(Mandatory)][object[]]$ItemList,
        [Parameter(Mandatory)][scriptblock]$Formatter
    )

    if ($ItemList.Count -eq 0) {
        return "$Title`: none."
    }

    $lineList = foreach ($item in $ItemList) {
        & $Formatter $item
    }

    return "$Title`:$([Environment]::NewLine)$($lineList -join [Environment]::NewLine)"
}

function Get-ScriptAnalyzerReportText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [Parameter(Mandatory)][object[]]$FindingList,
        [Parameter(Mandatory)][int]$AnalyzedFileCount
    )

    $severitySummary = @(
        $FindingList |
            Group-Object Severity |
            Sort-Object Name |
            ForEach-Object {
                [pscustomobject]@{
                    Severity = $_.Name
                    Count    = $_.Count
                }
            }
    )
    $ruleSummary = @(
        $FindingList |
            Group-Object RuleName |
            Sort-Object @{ Expression = { $_.Count }; Descending = $true }, @{ Expression = { $_.Name } } |
            ForEach-Object {
                [pscustomobject]@{
                    RuleName = $_.Name
                    Count    = $_.Count
                }
            }
    )
    $fileSummary = @(
        $FindingList |
            Group-Object RelativePath |
            Sort-Object @{ Expression = { $_.Count }; Descending = $true }, @{ Expression = { $_.Name } } |
            ForEach-Object {
                [pscustomobject]@{
                    RelativePath = $_.Name
                    Count        = $_.Count
                }
            }
    )
    $detailList = @(
        $FindingList |
            Sort-Object RelativePath, Line, RuleName
    )

    return @(
        "Analyzed files: $AnalyzedFileCount"
        "Total findings: $($FindingList.Count)"
        Get-ScriptAnalyzerReportSection `
            -Title 'Findings by severity' `
            -ItemList $severitySummary `
            -Formatter { param($item) '- {0}: {1}' -f $item.Severity, $item.Count }
        Get-ScriptAnalyzerReportSection `
            -Title 'Findings by rule' `
            -ItemList $ruleSummary `
            -Formatter { param($item) '- {0}: {1}' -f $item.RuleName, $item.Count }
        Get-ScriptAnalyzerReportSection `
            -Title 'Findings by file' `
            -ItemList $fileSummary `
            -Formatter { param($item) '- {0}: {1}' -f $item.RelativePath, $item.Count }
        Get-ScriptAnalyzerReportSection `
            -Title 'Detailed findings' `
            -ItemList $detailList `
            -Formatter {
                param($item)
                '- [{0}] {1}:{2} {3} - {4}' -f $item.Severity, $item.RelativePath, $item.Line, $item.RuleName, $item.Message
            }
    ) -join ([Environment]::NewLine * 2)
}

function Write-ScriptAnalyzerReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [AllowNull()]
        [AllowEmptyCollection()]
        [Parameter(Mandatory)][object[]]$FindingList,
        [Parameter(Mandatory)][int]$AnalyzedFileCount
    )

    $reportText = Get-ScriptAnalyzerReportText -FindingList $FindingList -AnalyzedFileCount $AnalyzedFileCount
    $reportText | Set-Content -LiteralPath $Path -Encoding utf8
}

function Invoke-ScriptAnalyzerCI {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$OutputDirectory
    )

    $repositoryRoot = Get-ScriptAnalyzerRepositoryRoot
    $analyzerVersion = Import-ScriptAnalyzerModule
    Confirm-ScriptAnalyzerVersion -AnalyzerVersion $analyzerVersion

    $analysisPathList = Get-ScriptAnalyzerAnalysisPathList -RepositoryRoot $repositoryRoot
    if ($analysisPathList.Count -eq 0) {
        throw "No PowerShell files were found to analyze under '$repositoryRoot'."
    }

    $resultList = @(Get-ScriptAnalyzerResultList -AnalysisPathList $analysisPathList)
    $findingList = @(ConvertTo-ScriptAnalyzerFindingRecordList -ResultList $resultList -RepositoryRoot $repositoryRoot)

    $resolvedOutputDirectory = Join-Path $repositoryRoot $OutputDirectory
    $null = New-Item -ItemType Directory -Path $resolvedOutputDirectory -Force
    $reportPath = Join-Path $resolvedOutputDirectory 'scriptanalyzer.txt'
    Write-ScriptAnalyzerReport -Path $reportPath -FindingList $findingList -AnalyzedFileCount $analysisPathList.Count

    if ($findingList.Count -gt 0) {
        throw "PSScriptAnalyzer reported $($findingList.Count) finding(s). See '$reportPath' for details."
    }

    return "PSScriptAnalyzer: 0 findings across $($analysisPathList.Count) file(s) with PSScriptAnalyzer $analyzerVersion."
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $message = Invoke-ScriptAnalyzerCI -OutputDirectory $OutputDirectory
        Write-Output $message
        exit 0
    } catch {
        Write-Error -ErrorRecord $_
        exit 1
    }
}
