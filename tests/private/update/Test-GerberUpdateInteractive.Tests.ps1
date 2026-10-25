BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $sourcePath = Join-Path $root 'src/private/update/Test-GerberUpdateInteractive.ps1'
    . $sourcePath
    $script:probeCommand = ". '$($sourcePath.Replace("'", "''"))'; Test-GerberUpdateInteractive"
    $script:powerShellPath = (Get-Process -Id $PID).Path
}

Describe 'Test-GerberUpdateInteractive' -Tag 'G4A7' {
    Context 'noninteractive safety' {
        It 'returns false in a noninteractive PowerShell process' {
            $result = & $script:powerShellPath -NoLogo -NoProfile -NonInteractive -Command $script:probeCommand

            $LASTEXITCODE | Should -Be 0
            $result | Should -BeExactly 'False'
        }

        It 'returns false when CI is set and restores the inherited value' {
            $previousCi = [Environment]::GetEnvironmentVariable('CI')
            try {
                $env:CI = 'true'

                Test-GerberUpdateInteractive | Should -BeFalse
            } finally {
                [Environment]::SetEnvironmentVariable('CI', $previousCi)
            }
        }
    }
}
