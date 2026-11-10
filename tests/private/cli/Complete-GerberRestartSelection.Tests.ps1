BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Complete-GerberRestartSelection' -Tag 'RestartHost' {
    BeforeEach {
        Mock Write-GerberScreenLine {}
        Mock Write-GerberPromptTrace {}
        Mock Stop-GerberPowerShellHost {}
    }

    It 'continues without a signal or closing anything' {
        @(Complete-GerberRestartSelection -Selection 'continue' -Guidance 'g').Count | Should -Be 0
        Should -Invoke Stop-GerberPowerShellHost -Times 0
    }

    It 'returns exactly one exit signal for Exit Gerber and leaves PowerShell open' {
        @(Complete-GerberRestartSelection -Selection 'exit' -Guidance 'Guidance text') | Should -Be @($true)
        Should -Invoke Write-GerberScreenLine -ParameterFilter { $Text -eq 'Exiting Gerber. Guidance text' }
        Should -Invoke Stop-GerberPowerShellHost -Times 0
    }

    It 'closes the PowerShell host after tracing the selection for Exit Gerber and PowerShell' {
        @(Complete-GerberRestartSelection -Selection 'exit-host' -Guidance 'g') | Should -Be @($true)
        Should -Invoke Write-GerberScreenLine -ParameterFilter { $Text -match 'Closing PowerShell' }
        Should -Invoke Stop-GerberPowerShellHost -Times 1
    }
}
