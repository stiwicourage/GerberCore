BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberRootCommandNameList' -Tag 'G4A7' {
    It 'places the reserved commands first in a fixed order and sorts the rest alphabetically' {
        $result = Get-GerberRootCommandNameList -ValueList @('tools', 'secrets', 'plugins', 'ado', 'help', 'exit', 'list', 'update')

        $result | Should -Be @('exit', 'help', 'plugins', 'update', 'ado', 'list', 'secrets', 'tools')
    }

    It 'only reserves commands that are present' {
        Get-GerberRootCommandNameList -ValueList @('zeta', 'plugins', 'alpha') | Should -Be @('plugins', 'alpha', 'zeta')
    }

    It 'returns an empty list for no input' {
        @(Get-GerberRootCommandNameList -ValueList @()).Count | Should -Be 0
    }
}
