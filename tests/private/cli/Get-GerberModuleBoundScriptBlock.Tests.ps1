BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberModuleBoundScriptBlock' {
    It 'captures local variables even when no module session state is available' {
        $value = 'captured'
        $operation = Get-GerberModuleBoundScriptBlock -ScriptBlock ({
            return $value
        }.GetNewClosure())

        (& $operation) | Should -Be 'captured'
    }
}
