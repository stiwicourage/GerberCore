BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Request-GerberVisibleRootPrompt' {
    BeforeEach {
        $script:GerberPendingRootPromptBuffer = $null
        Mock Write-GerberPromptTrace {}
    }

    It 'stores the slash buffer for the next root prompt render' {
        Request-GerberVisibleRootPrompt

        $script:GerberPendingRootPromptBuffer | Should -Be '/'
        Should -Invoke Write-GerberPromptTrace -Times 1 -ParameterFilter { $EventName -eq 'root-prompt-request' }
    }
}
