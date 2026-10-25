BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Resolve-GerberConfigPath' {
    It 'defaults to the local .gerber config file' {
        $result = Resolve-GerberConfigPath

        $result | Should -Match '\.gerber[/\\]config\.json$'
    }

    It 'resolves an explicit path to its absolute full path' {
        $result = Resolve-GerberConfigPath -Path (Join-Path $TestDrive 'config.json')

        $result | Should -Match 'config\.json$'
    }
}
