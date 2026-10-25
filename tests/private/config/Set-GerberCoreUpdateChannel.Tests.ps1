BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Set-GerberCoreUpdateChannel' -Tag 'CoreUpdatePolicy' {
    BeforeEach {
        $script:configuration = @{ schemaVersion = 1; preferences = @{ theme = 'dark' }; updates = @{ modules = @{ Gerber = @{ repository = 'Ignored' } } } }
        Mock Get-GerberUserConfiguration { $script:configuration }
        Mock Save-GerberUserConfiguration {}
        $script:GerberStartupUpdateState = [pscustomobject]@{ Status = 'Available'; Available = '0.2.0' }
    }

    AfterEach {
        Remove-Variable GerberStartupUpdateState -Scope Script -ErrorAction SilentlyContinue
    }

    Context 'atomic persistence and notification invalidation' {
        It 'preserves unrelated and legacy settings and clears the old notification only after saving' {
            Set-GerberCoreUpdateChannel -Channel IncludePrerelease | Should -BeTrue
            Should -Invoke Save-GerberUserConfiguration -Times 1 -ParameterFilter {
                $Configuration.coreUpdates.channel -ceq 'IncludePrerelease' -and
                $Configuration.preferences.theme -eq 'dark' -and $Configuration.updates.modules.Gerber.repository -eq 'Ignored'
            }
            Get-Variable GerberStartupUpdateState -Scope Script -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }

        It 'does not write or invalidate a notification when reselecting the effective default' {
            Set-GerberCoreUpdateChannel -Channel Stable | Should -BeFalse
            Should -Invoke Save-GerberUserConfiguration -Times 0
            $script:GerberStartupUpdateState.Available | Should -BeExactly '0.2.0'
        }

        It 'preserves other core settings when switching back to Stable' {
            $script:configuration.coreUpdates = @{ channel = 'IncludePrerelease'; futureOption = 'preserved' }
            Set-GerberCoreUpdateChannel -Channel Stable | Should -BeTrue
            Should -Invoke Save-GerberUserConfiguration -Times 1 -ParameterFilter {
                $Configuration.coreUpdates.channel -ceq 'Stable' -and $Configuration.coreUpdates.futureOption -eq 'preserved'
            }
        }

        It 'propagates a save failure without clearing the startup notification' {
            Mock Save-GerberUserConfiguration { throw [IO.IOException]::new('Cannot write') }
            { Set-GerberCoreUpdateChannel -Channel IncludePrerelease } | Should -Throw '*Cannot write*'
            $script:GerberStartupUpdateState.Available | Should -BeExactly '0.2.0'
        }

        It 'preserves configuration and notifications when ShouldProcess declines' {
            Set-GerberCoreUpdateChannel -Channel IncludePrerelease -WhatIf | Should -BeFalse
            $script:configuration.Contains('coreUpdates') | Should -BeFalse
            Should -Invoke Save-GerberUserConfiguration -Times 0
            $script:GerberStartupUpdateState.Available | Should -BeExactly '0.2.0'
        }
    }
}
