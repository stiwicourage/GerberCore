BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    . (Join-Path $root 'src/private/cli/Assert-GerberPluginRegistrationIdentity.ps1')
}

Describe 'Assert-GerberPluginRegistrationIdentity' -Tag 'PluginTransactions' {
    Context 'Module-name boundary' {
        It 'allows an empty registry and the same plugin identity' {
            $module = [pscustomobject]@{ Name = 'Gerber.A'; Guid = 'first-guid' }

            { Assert-GerberPluginRegistrationIdentity -PluginList @() -PluginModule $module } | Should -Not -Throw
            { Assert-GerberPluginRegistrationIdentity -PluginList @($module) -PluginModule $module } | Should -Not -Throw
        }

        It 'rejects another GUID using a case-insensitive active name' {
            $active = [pscustomobject]@{ Name = 'Gerber.A'; Guid = 'first-guid' }
            $module = [pscustomobject]@{ Name = 'gerber.a'; Guid = 'second-guid' }

            { Assert-GerberPluginRegistrationIdentity -PluginList @($active) -PluginModule $module } |
                Should -Throw '*module name*first-guid*'
        }
    }
}
