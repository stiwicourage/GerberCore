# Contract ownership and real operation scriptblocks span Core source files;
# the public validator tests and installed-command integration cover packaging.
BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberPluginBoundaryContract' -Tag 'PluginBoundary' {
    It 'derives actual private sibling ownership and public capabilities without prefix bans' {
        $contract = Get-GerberPluginBoundaryContract
        $contract.PrivateCommands.ContainsKey('Get-GerberCommandRegistry') | Should -BeTrue
        $contract.PrivateCommands.ContainsKey('Assert-GerberGeneratedSourceBoundary') | Should -BeTrue
        $contract.PrivateCommands.ContainsKey('Test-GerberPluginBoundary') | Should -BeFalse
        $contract.PrivateCommands.ContainsKey('Get-GerberImaginaryCommand') | Should -BeFalse
        $contract.PublicApi.Secrets | Should -Contain 'GetText'
        $contract.PublicApi.Clipboard | Should -Contain 'CopyText'
    }
}
