BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    . "$root/src/private/update/Show-GerberStartupUpdateNotification.ps1"
    . "$root/src/private/cli/Write-GerberScreenLine.ps1"
}

Describe 'Show-GerberStartupUpdateNotification' -Tag 'G4A7' {
    AfterEach { Remove-Variable GerberStartupUpdateState -Scope Script -ErrorAction SilentlyContinue }

    Context 'root redraw notification' {
        It 'renders the available Core version with the manual review command' {
            Mock Get-Variable { [pscustomobject]@{ Status = 'Available'; Available = '0.2.0' } } -ParameterFilter {
                $Name -eq 'GerberStartupUpdateState' -and $Scope -eq 'Script'
            }
            Mock Write-GerberScreenLine {}
            Show-GerberStartupUpdateNotification
            Should -Invoke Write-GerberScreenLine -Times 1 -Exactly -ParameterFilter {
                $Text -ceq 'Gerber Core 0.2.0 is available. Run /update list to review.'
            }
        }

        It 'keeps available version and /update list visible on successive redraws' {
            $script:GerberStartupUpdateState = [pscustomobject]@{ Status = 'Available'; Available = '0.2.0-preview' }
            Mock Write-GerberScreenLine {}
            Show-GerberStartupUpdateNotification
            Show-GerberStartupUpdateNotification
            Should -Invoke Write-GerberScreenLine -Times 2 -ParameterFilter { $Text -match '0.2.0-preview.* /update list' }
        }

        It 'does not label unknown/unconfigured status as up to date' -ForEach @('Unavailable', 'Unconfigured', 'UpToDate') {
            $script:GerberStartupUpdateState = [pscustomobject]@{ Status = $_ }
            Mock Write-GerberScreenLine {}
            Show-GerberStartupUpdateNotification
            Should -Invoke Write-GerberScreenLine -Times 0
        }
    }
}
