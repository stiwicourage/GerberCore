BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    . "$root/src/private/update/Test-GerberUpdateInteractive.ps1"
}

Describe 'Test-GerberUpdateInteractive' -Tag 'G4A7' {
    Context 'noninteractive safety' {
        It 'returns false under the redirected Nova runner' {
            Test-GerberUpdateInteractive | Should -BeFalse
        }
    }
}
