BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Confirm-GerberPluginDevelopmentTool' -Tag 'PluginCreate' {
    BeforeEach {
        Mock Get-Module { @() } -ParameterFilter { $ListAvailable -and $Name -eq 'NovaModuleTools' }
        Mock Read-GerberConfirmationPrompt { $false }
        Mock Install-Module {}
    }

    It 'declines installation without creating files or approving anything' {
        Confirm-GerberPluginDevelopmentTool | Should -BeFalse
        Should -Invoke Install-Module -Times 0
    }

    It 'installs only after explicit consent and verifies availability' {
        Mock Read-GerberConfirmationPrompt { $true }
        Mock Install-Module {
            Mock Get-Module { [pscustomobject]@{ Version = [version]'3.4.1' } } -ParameterFilter {
                $ListAvailable -and $Name -eq 'NovaModuleTools'
            }
        }
        Confirm-GerberPluginDevelopmentTool | Should -BeTrue
        Should -Invoke Install-Module -Times 1 -ParameterFilter { $Name -eq 'NovaModuleTools' }
    }

    It 'does not prompt or install when Nova is already available' {
        Mock Get-Module { [pscustomobject]@{ Version = [version]'3.4.1' } } -ParameterFilter {
            $ListAvailable -and $Name -eq 'NovaModuleTools'
        }
        Confirm-GerberPluginDevelopmentTool | Should -BeTrue
        Should -Invoke Read-GerberConfirmationPrompt -Times 0
        Should -Invoke Install-Module -Times 0
    }
}
