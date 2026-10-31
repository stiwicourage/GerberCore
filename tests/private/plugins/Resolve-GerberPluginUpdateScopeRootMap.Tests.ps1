BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    . (Join-Path $root 'src/private/plugins/Resolve-GerberPluginUpdateScopeRootMap.ps1')
}

Describe 'Resolve-GerberPluginUpdateScopeRootMap' -Tag 'G4A9' {
    It 'provides distinct absolute roots without changing process environment' {
        $before = [Environment]::GetEnvironmentVariable('XDG_DATA_HOME')
        $roots = Resolve-GerberPluginUpdateScopeRootMap
        [IO.Path]::IsPathRooted($roots.CurrentUser) | Should -BeTrue
        [IO.Path]::IsPathRooted($roots.AllUsers) | Should -BeTrue
        $roots.CurrentUser | Should -Not -Be $roots.AllUsers
        [Environment]::GetEnvironmentVariable('XDG_DATA_HOME') | Should -Be $before
    }
}
