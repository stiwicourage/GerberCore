BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    . (Join-Path $root 'src/private/cli/Copy-GerberCommandRegistryState.ps1')
    . (Join-Path $root 'src/private/cli/Copy-GerberCommandRegistryValue.ps1')
}

Describe 'Copy-GerberCommandRegistryState' -Tag 'PluginTransactions' {
    Context 'Independent staging' {
        It 'preserves shared child tables across flat and nested commands without cloning runtime contexts' {
            $child = [pscustomobject]@{ Subcommands = [ordered]@{}; Handler = { return $true } }
            $parent = [pscustomobject]@{ Subcommands = [ordered]@{ child = @{ Subcommands = $child.Subcommands; Description = 'child' } } }
            $context = [pscustomobject]@{ Marker = 'live' }
            $state = [pscustomobject]@{
                CommandList = @($parent, $child)
                PluginList = @([pscustomobject]@{ PluginApiContext = $context })
                GerberVersion = '1.0.0'
            }

            $copy = Copy-GerberCommandRegistryState -State $state

            [object]::ReferenceEquals($copy.CommandList[0].Subcommands.child.Subcommands, $copy.CommandList[1].Subcommands) | Should -BeTrue
            [object]::ReferenceEquals($copy.CommandList[1].Subcommands, $child.Subcommands) | Should -BeFalse
            [object]::ReferenceEquals($copy.PluginList[0].PluginApiContext, $context) | Should -BeTrue
            $copy.GerberVersion | Should -Be '1.0.0'
        }

        It 'preserves empty command and plugin collections' {
            $state = [pscustomobject]@{ CommandList = @(); PluginList = @(); GerberVersion = '1.0.0' }

            $copy = Copy-GerberCommandRegistryState -State $state

            $copy.CommandList.Count | Should -Be 0
            $copy.PluginList.Count | Should -Be 0
        }
    }
}
