BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Show-GerberTextBlock' {
    It 'clears the screen and writes the title, spacer, and text' {
        Mock Start-GerberScreen {}
        Mock Write-GerberScreenLine {}

        Show-GerberTextBlock -Title '/help' -Text 'Help text'

        Should -Invoke Start-GerberScreen -Times 1 -ParameterFilter { $Name -eq '/help' }
        Should -Invoke Write-GerberScreenLine -Times 3
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq '/help' }
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq 'Help text' }
    }
}
