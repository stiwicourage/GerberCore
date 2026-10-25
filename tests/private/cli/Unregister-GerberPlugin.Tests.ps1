BeforeAll {
    $supportPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers'
    . (Join-Path $supportPath 'GerberTestSupport.ps1')
    . (Join-Path $supportPath 'Get-GerberPluginTransactionCommand.ps1')
    . (Join-Path $supportPath 'Get-GerberRegistryTransactionSnapshot.ps1')
    . (Join-Path $supportPath 'Get-GerberRegistryTransactionModuleList.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
    $script:clearSubcommand = ${function:Clear-GerberPluginSubcommandEntry}
}

Describe 'Unregister-GerberPlugin' -Tag 'PluginTransactions' {
    BeforeEach {
        Clear-GerberCommandRegistry
        $null = Initialize-GerberCommandRegistry -PluginModulePathList @()
        $script:moduleA, $script:moduleB = Get-GerberRegistryTransactionModuleList -StartPath $PSScriptRoot
        $script:definition = [pscustomobject]@{ Commands = @(Get-GerberPluginTransactionCommand 'repository shared') }
        Mock Get-GerberPluginDefinition { $script:definition }
    }

    AfterEach {
        Clear-GerberCommandRegistry
    }

    AfterAll {
        $null = Initialize-GerberCommandRegistry -PluginModulePathList @()
    }

    Context 'Plugin removal boundaries' {
        It 'lets two plugins share a Core parent and preserves the other on unregister' {
            Register-GerberPlugin -PluginModule $script:moduleA
            $script:definition.Commands = @(Get-GerberPluginTransactionCommand 'repository other')
            Register-GerberPlugin -PluginModule $script:moduleB

            Unregister-GerberPlugin -Guid $script:moduleA.Guid

            Get-GerberRegisteredCommand -Name 'repository shared' | Should -BeNullOrEmpty
            (Resolve-GerberCommand '/repository other').IsValid | Should -BeTrue
            $command = Get-GerberRegisteredCommand -Name 'repository other'
            Invoke-GerberRegisteredCommand -CommandDefinition $command -Command ([pscustomobject]@{ Name = $command.Name }) | Should -BeTrue
            @($script:GerberCommandRegistryState.PluginList).Guid | Should -Be @($script:moduleB.Guid)
        }

        It 'keeps published nested tables unchanged when unregister preparation partially mutates its stage' {
            Register-GerberPlugin -PluginModule $script:moduleA
            $before = Get-GerberRegistryTransactionSnapshot
            Mock Clear-GerberPluginSubcommandEntry {
                & $script:clearSubcommand -CommandList $CommandList -OwnedCommand $OwnedCommand
                throw 'unregister preparation fault'
            }

            { Unregister-GerberPlugin -Guid $script:moduleA.Guid } | Should -Throw '*unregister preparation fault*'

            Get-GerberRegistryTransactionSnapshot | Should -Be $before
            (Get-GerberRegisteredCommand -Name 'repository').Subcommands.Contains('shared') | Should -BeTrue
        }
    }

    Context 'Strict-mode parent removal' {
        It 'removes plugin commands whose parent is another command of the same plugin' {
            $pipelines = ConvertTo-GerberOwnedCommandDefinition `
                -CommandDefinition (Get-GerberPluginTransactionCommand 'pipelines') -OwnerName 'Gerber' -OwnerType Core
            $release = ConvertTo-GerberOwnedCommandDefinition `
                -CommandDefinition (Get-GerberPluginTransactionCommand 'pipelines release') -OwnerName 'Gerber.X' -OwnerType Plugin
            $child = ConvertTo-GerberOwnedCommandDefinition `
                -CommandDefinition (Get-GerberPluginTransactionCommand 'pipelines release approve') -OwnerName 'Gerber.X' -OwnerType Plugin
            $pipelines.Subcommands['release'] = [pscustomobject]@{}
            $script:GerberCommandRegistryState = [pscustomobject]@{
                CommandList = @($pipelines, $release, $child)
                PluginList = @([pscustomobject]@{ Guid = $script:moduleA.Guid; Name = 'Gerber.X' })
                GerberVersion = '1.0.0'
            }

            Set-StrictMode -Version Latest
            try {
                Unregister-GerberPlugin -Guid $script:moduleA.Guid
            } finally {
                Set-StrictMode -Off
            }

            @($script:GerberCommandRegistryState.CommandList).Name | Should -Be @('pipelines')
            (Get-GerberRegisteredCommand -Name 'pipelines').Subcommands.Contains('release') | Should -BeFalse
            $pipelines.Subcommands.Contains('release') | Should -BeTrue
        }
    }
}
