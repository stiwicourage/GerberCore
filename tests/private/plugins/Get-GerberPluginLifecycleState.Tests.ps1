BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberPluginLifecycleState' {
    It 'treats a plugin without an association record as loadable' {
        $state = Get-GerberPluginLifecycleState `
            -Configuration @{ schemaVersion = 1 } `
            -Guid '6996218c-58d0-48ce-b6cc-38d06149230a'

        $state.Guid | Should -Be '6996218c-58d0-48ce-b6cc-38d06149230a'
        $state.IsAssociated | Should -BeFalse
        $state.IsEnabled | Should -BeTrue
        $state.ShouldLoad | Should -BeTrue
    }

    It 'returns a disabled associated plugin as not loadable' {
        $state = Get-GerberPluginLifecycleState `
            -Configuration @{
                schemaVersion = 1
                plugins = @{
                    associated = @{
                        '6996218c-58d0-48ce-b6cc-38d06149230a' = @{
                            enabled = $false
                        }
                    }
                }
            } `
            -Guid '6996218c-58d0-48ce-b6cc-38d06149230a'

        $state.IsAssociated | Should -BeTrue
        $state.IsEnabled | Should -BeFalse
        $state.ShouldLoad | Should -BeFalse
    }

    It 'rejects an invalid plugin GUID' {
        {
            Get-GerberPluginLifecycleState -Configuration @{ schemaVersion = 1 } -Guid 'not-a-guid'
        } | Should -Throw '*invalid GUID*'
    }
}
