BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
    $script:AliasGuid = '6996218c-58d0-48ce-b6cc-38d06149230a'
    $script:OtherGuid = '977537c5-b7f5-4f2f-9dd4-5ec0e28d2618'
}

Describe 'Get-GerberPluginNamespaceAlias' {
    It 'returns the alias stored for the plugin GUID' {
        $configuration = @{ schemaVersion = 1; plugins = @{ aliases = @{ $script:AliasGuid = 'microsoft-ado' } } }

        Get-GerberPluginNamespaceAlias -Configuration $configuration -Guid $script:AliasGuid.ToUpperInvariant() |
            Should -Be 'microsoft-ado'
    }

    It 'returns null when no alias is stored' {
        Get-GerberPluginNamespaceAlias -Configuration @{ schemaVersion = 1 } -Guid $script:AliasGuid |
            Should -BeNullOrEmpty
    }
}

Describe 'Set-GerberPluginNamespaceAlias' {
    BeforeEach {
        $script:ConfigPath = Join-Path $TestDrive 'config.json'
        Mock Resolve-GerberUserConfigPath { $script:ConfigPath }
    }

    It 'persists the alias by GUID and keeps it independent of plugin version metadata' {
        $configuration = @{ schemaVersion = 1 }

        Set-GerberPluginNamespaceAlias -Configuration $configuration -Guid $script:AliasGuid -Alias 'microsoft-ado'

        (Get-GerberUserConfiguration).plugins.aliases[$script:AliasGuid] | Should -Be 'microsoft-ado'
    }

    It 'removes the alias when none is given' {
        $configuration = @{ schemaVersion = 1; plugins = @{ aliases = @{ $script:AliasGuid = 'microsoft-ado' } } }

        Set-GerberPluginNamespaceAlias -Configuration $configuration -Guid $script:AliasGuid -Alias $null

        $configuration.plugins.aliases.Contains($script:AliasGuid) | Should -BeFalse
    }

    It 'rejects <Alias>' -ForEach @(
        @{ Alias = 'Bad Name' }
        @{ Alias = '1abc' }
        @{ Alias = 'plugins' }
        @{ Alias = 'Update' }
    ) {
        { Set-GerberPluginNamespaceAlias -Configuration @{ schemaVersion = 1 } -Guid $script:AliasGuid -Alias $Alias } |
            Should -Throw
    }

    It 'rejects an alias already used by another plugin' {
        $configuration = @{ schemaVersion = 1; plugins = @{ aliases = @{ $script:OtherGuid = 'microsoft-ado' } } }

        { Set-GerberPluginNamespaceAlias -Configuration $configuration -Guid $script:AliasGuid -Alias 'microsoft-ado' } |
            Should -Throw "*already used*"
    }
}

Describe 'Rename-GerberPluginCommandRoot' {
    It 'renames the root of every command and keeps the rest of the path' {
        $definitionList = @(
            [pscustomobject]@{ Name = 'ado'; Description = 'd'; Handler = {}; Subcommands = [ordered]@{} }
            [pscustomobject]@{ Name = 'ado repo list'; Description = 'd'; Handler = {}; Subcommands = [ordered]@{} }
        )

        $result = @(Rename-GerberPluginCommandRoot -CommandDefinitionList $definitionList -Alias 'microsoft-ado' -PluginName 'Gerber.X')

        $result.Name | Should -Be @('microsoft-ado', 'microsoft-ado repo list')
    }

    It 'returns the definitions unchanged when the plugin has more than one root' {
        $definitionList = @(
            [pscustomobject]@{ Name = 'a'; Description = 'd'; Handler = {}; Subcommands = [ordered]@{} }
            [pscustomobject]@{ Name = 'b'; Description = 'd'; Handler = {}; Subcommands = [ordered]@{} }
        )

        $result = @(Rename-GerberPluginCommandRoot -CommandDefinitionList $definitionList -Alias 'x' -PluginName 'Gerber.X' -WarningAction SilentlyContinue)

        $result.Name | Should -Be @('a', 'b')
    }
}

Describe 'Test-GerberPluginUserConfiguration aliases' {
    It 'rejects an invalid alias value' {
        $configuration = @{ schemaVersion = 1; plugins = @{ aliases = @{ $script:AliasGuid = 'Not Valid' } } }

        { Test-GerberPluginUserConfiguration -Configuration $configuration -Path 'c.json' } | Should -Throw "*plugins.aliases*"
    }

    It 'rejects a duplicate alias' {
        $configuration = @{ schemaVersion = 1; plugins = @{ aliases = @{ $script:AliasGuid = 'dup'; $script:OtherGuid = 'dup' } } }

        { Test-GerberPluginUserConfiguration -Configuration $configuration -Path 'c.json' } | Should -Throw "*duplicate*"
    }

    It 'accepts valid aliases' {
        $configuration = @{ schemaVersion = 1; plugins = @{ aliases = @{ $script:AliasGuid = 'microsoft-ado' } } }

        Test-GerberPluginUserConfiguration -Configuration $configuration -Path 'c.json' | Should -BeTrue
    }
}
