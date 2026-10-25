[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),

    [string]$ManifestPath = (Join-Path $PSScriptRoot 'Sync-AgenticCopilotScaffold.psd1')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-AgenticSyncPath {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RootPath,

        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    return [System.IO.Path]::GetFullPath((Join-Path $RootPath $RelativePath))
}

function Get-AgenticMirrorContent {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory)]
        [string]$SourceRelativePath
    )

    $sourcePath = Resolve-AgenticSyncPath -RootPath $RepositoryRoot -RelativePath $SourceRelativePath
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Agentic scaffold source does not exist: $SourceRelativePath"
    }

    $sourceContent = Get-Content -LiteralPath $sourcePath -Raw
    $banner = "<!-- Generated from $SourceRelativePath by scripts/build/Sync-AgenticCopilotScaffold.ps1. Do not edit by hand. -->`n`n"
    return $banner + $sourceContent
}

function Write-AgenticMirrorFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory)]
        [string]$RelativePath,

        [Parameter(Mandatory)]
        [string]$Content
    )

    $targetPath = Resolve-AgenticSyncPath -RootPath $RepositoryRoot -RelativePath $RelativePath
    $targetDirectory = Split-Path -Parent $targetPath
    if (-not (Test-Path -LiteralPath $targetDirectory -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $targetDirectory -Force
    }

    Set-Content -LiteralPath $targetPath -Value $Content -Encoding utf8 -NoNewline
}

$resolvedRepositoryRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
$resolvedManifestPath = [System.IO.Path]::GetFullPath($ManifestPath)
$manifest = Import-PowerShellDataFile -LiteralPath $resolvedManifestPath

foreach ($mirror in @($manifest.GeneratedMirrors)) {
    $content = Get-AgenticMirrorContent -RepositoryRoot $resolvedRepositoryRoot -SourceRelativePath $mirror.Source
    Write-AgenticMirrorFile -RepositoryRoot $resolvedRepositoryRoot -RelativePath $mirror.Target -Content $content
}
