# Actual Nova build/test plus built Core registration spans multiple files and
# is covered by New-GerberPluginProject.Integration.Tests.ps1, without mocks.
BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Test-GerberPluginProject' -Tag 'PluginCreate' {
    It 'accepts valid authored source before the existing generated-project lifecycle' -Tag 'PluginBoundary' {
        $path = Join-Path $TestDrive 'valid'
        $null = New-Item -ItemType Directory "$path/src/private" -Force
        Set-Content "$path/src/private/Valid.ps1" 'Get-ChildItem'
        { Assert-GerberGeneratedSourceBoundary -Path $path } | Should -Not -Throw
    }

    It 'rejects actual private dependencies before Nova execution or registration' -Tag 'PluginBoundary' {
        $path = Join-Path $TestDrive 'invalid'
        $null = New-Item -ItemType Directory "$path/src/private" -Force
        Set-Content "$path/src/private/Invalid.ps1" 'Get-GerberCommandRegistry'
        Mock Assert-GerberGeneratedPluginRegistration {}
        $request = [pscustomobject]@{ Name = 'Gerber.Invalid' }
        { Test-GerberPluginProject -Request $request -Path $path -Guid ([guid]::NewGuid()) } |
            Should -Throw '*src/private/Invalid.ps1:1*Get-GerberCommandRegistry*'
        Should -Invoke Assert-GerberGeneratedPluginRegistration -Times 0
    }

    It 'ships the managed child validator with the templates' {
        $scriptPath = Join-Path (Get-GerberPluginTemplatePath) '../Test-GerberGeneratedProject.ps1'
        $text = Get-Content $scriptPath -Raw
        $text | Should -Match 'Invoke-NovaBuild'
        $text | Should -Match 'Invoke-NovaTest'
        $text | Should -Match 'Test-NovaBuild'
        $text | Should -Not -Match 'Invoke-Pester'
    }
}
