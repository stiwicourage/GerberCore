BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    . (Join-Path $root 'src/private/cli/Assert-GerberPluginCommandRootNotReserved.ps1')
}

Describe 'Assert-GerberPluginCommandRootNotReserved' -Tag 'G3B' {
    It 'rejects <Name> because its root <Root> is reserved for Gerber Core' -ForEach @(
        @{ Name = 'plugins extra'; Root = 'plugins' }
        @{ Name = 'Update list'; Root = 'update' }
        @{ Name = 'exit now'; Root = 'exit' }
        @{ Name = 'help topic'; Root = 'help' }
        @{ Name = 'tools hash'; Root = 'tools' }
        @{ Name = 'secrets add'; Root = 'secrets' }
    ) {
        $definition = @([pscustomobject]@{ Name = $Name })

        { Assert-GerberPluginCommandRootNotReserved -CommandDefinitionList $definition -PluginName 'Gerber.Demo' } |
            Should -Throw "*Gerber.Demo*'$Name'*'$Root'*reserved*"
    }

    It 'allows unreserved roots, empty lists and bare roots left to the owner-conflict check' {
        $definitionList = @([pscustomobject]@{ Name = 'ado' }, [pscustomobject]@{ Name = 'ado list' }, [pscustomobject]@{ Name = 'plugins' })

        { Assert-GerberPluginCommandRootNotReserved -CommandDefinitionList $definitionList -PluginName 'Gerber.Demo' } | Should -Not -Throw
        { Assert-GerberPluginCommandRootNotReserved -CommandDefinitionList @() -PluginName 'Gerber.Demo' } | Should -Not -Throw
    }
}
