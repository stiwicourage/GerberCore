BeforeAll {
    $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:scriptPath = Join-Path $repositoryRoot 'scripts/build/Sync-AgenticCopilotScaffold.ps1'

    function Write-SyncFixture {
        param([string]$Root, [switch]$OmitSource)
        $null = New-Item -ItemType Directory -Path (Join-Path $Root '.github') -Force
        if (-not $OmitSource) {
            Set-Content -LiteralPath (Join-Path $Root '.github/source.md') -Value '# Source' -NoNewline
        }
        $manifest = Join-Path $Root 'manifest.psd1'
        Set-Content -LiteralPath $manifest -Value "@{ GeneratedMirrors = @(@{ Source = '.github/source.md'; Target = 'out/MIRROR.md' }) }"
        return $manifest
    }
}

Describe 'Sync-AgenticCopilotScaffold' -Tag 'BuildTooling' {
    It 'writes the mirror with a generated banner and creates the target directory' {
        $root = Join-Path $TestDrive 'ok'
        $manifest = Write-SyncFixture -Root $root

        & $script:scriptPath -RepositoryRoot $root -ManifestPath $manifest

        $expected = "<!-- Generated from .github/source.md by scripts/build/Sync-AgenticCopilotScaffold.ps1. Do not edit by hand. -->`n`n# Source"
        Get-Content -LiteralPath (Join-Path $root 'out/MIRROR.md') -Raw | Should -Be $expected
    }

    It 'fails when the mirror source is missing' {
        $root = Join-Path $TestDrive 'missing'
        $manifest = Write-SyncFixture -Root $root -OmitSource

        { & $script:scriptPath -RepositoryRoot $root -ManifestPath $manifest } |
            Should -Throw '*source does not exist*'
    }
}
