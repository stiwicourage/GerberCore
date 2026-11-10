BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    . "$root/src/private/update/Get-GerberPmuInstallOption.ps1"
}

Describe 'Get-GerberPmuInstallOption' {
    It 'opts in to replacing unmanaged installations when PMU supports it' {
        Mock Get-Command {
            [pscustomobject]@{ Parameters = @{ ReplaceUnmanagedInstallation = $true } }
        }
        $option = Get-GerberPmuInstallOption
        $option.ReplaceUnmanagedInstallation | Should -BeTrue
    }

    It 'passes nothing extra to an older PMU without the switch' {
        Mock Get-Command {
            [pscustomobject]@{ Parameters = @{ Update = $true } }
        }
        (Get-GerberPmuInstallOption).Count | Should -Be 0
    }
}
