# The real multi-field input, defaults, recovery and shared Escape contract are
# exercised by Invoke-GerberPluginsCreateCommand.Tests.ps1 across the UI helpers.
BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Read-GerberPluginProjectRequest' -Tag 'PluginCreate' {
    It 'returns validated input from shared prompts' {
        $script:values = [System.Collections.Generic.Queue[string]]::new([string[]]@('Example', 'Tools', 'example', $TestDrive))
        Mock Read-GerberCommand { $script:values.Dequeue() }
        $request = Read-GerberPluginProjectRequest
        $request.Name | Should -Be 'Gerber.Example'
        $request.Destination | Should -Be (Join-Path $TestDrive 'Gerber.Example')
    }

    It 'renders the first field under built-module StrictMode before the suffix exists' -Tag 'PluginCreateStrict' {
        $script:values = [System.Collections.Generic.Queue[string]]::new([string[]]@('Example', 'Tools', 'example', $TestDrive))
        Mock Read-GerberCommand { $script:values.Dequeue() }
        Mock Write-GerberScreenLine {}
        $request = & {
            Set-StrictMode -Version Latest
            Read-GerberPluginProjectRequest
        }
        $request.Name | Should -Be 'Gerber.Example'
    }
}
