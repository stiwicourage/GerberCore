BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    . (Join-Path $root 'src/private/cli/Resolve-GerberPluginNamespaceConflict.ps1')
    $script:newBuilder = {
        param([object[]]$CommandList)
        [pscustomobject]@{ CommandList = [System.Collections.Generic.List[object]]::new([object[]]$CommandList) }
    }
    $script:owned = {
        param([string]$Name, [string]$Owner)
        [pscustomobject]@{ Name = $Name; OwnerName = $Owner; OwnerType = 'Plugin' }
    }
}

Describe 'Resolve-GerberPluginNamespaceConflict' -Tag 'G3B' {
    It 'returns every definition and warns about nothing when no other plugin owns the root' {
        $builder = & $script:newBuilder @(& $script:owned 'other' 'Gerber.B')
        $incoming = @([pscustomobject]@{ Name = 'ado' }, [pscustomobject]@{ Name = 'ado list' })

        $result = @(Resolve-GerberPluginNamespaceConflict -RegistryBuilder $builder -CommandDefinitionList $incoming -OwnerName 'Gerber.A' -WarningVariable w -WarningAction SilentlyContinue)

        $result.Count | Should -Be 2
        @($w).Count | Should -Be 0
        $builder.CommandList.Count | Should -Be 1
    }

    It 'withholds the root from both plugins, case-insensitively, and warns once naming both' {
        $builder = & $script:newBuilder @((& $script:owned 'ado' 'Gerber.A'), (& $script:owned 'ado list' 'Gerber.A'), (& $script:owned 'keep' 'Gerber.A'))
        $incoming = @([pscustomobject]@{ Name = 'ADO' }, [pscustomobject]@{ Name = 'ADO run' }, [pscustomobject]@{ Name = 'other' })

        $result = @(Resolve-GerberPluginNamespaceConflict -RegistryBuilder $builder -CommandDefinitionList $incoming -OwnerName 'Gerber.B' -WarningVariable w -WarningAction SilentlyContinue)

        $result.Name | Should -Be @('other')
        $builder.CommandList.Name | Should -Be @('keep')
        @($w).Count | Should -Be 1
        "$w" | Should -BeLike "*'/ado'*Gerber.A*Gerber.B*"
    }

    It 'keeps withholding the root for a third plugin' {
        $builder = & $script:newBuilder @((& $script:owned 'ado' 'Gerber.A'))
        $null = Resolve-GerberPluginNamespaceConflict -RegistryBuilder $builder -CommandDefinitionList @([pscustomobject]@{ Name = 'ado' }) -OwnerName 'Gerber.B' -WarningAction SilentlyContinue

        $result = @(Resolve-GerberPluginNamespaceConflict -RegistryBuilder $builder -CommandDefinitionList @([pscustomobject]@{ Name = 'ado' }) -OwnerName 'Gerber.C' -WarningVariable w -WarningAction SilentlyContinue)

        $result.Count | Should -Be 0
        "$w" | Should -BeLike '*Gerber.A*Gerber.B*Gerber.C*'
    }

    It 'allows plugins to share a parent container without declaring the same root command' {
        $builder = & $script:newBuilder @(& $script:owned 'repository shared' 'Gerber.A')

        @(Resolve-GerberPluginNamespaceConflict -RegistryBuilder $builder -CommandDefinitionList @([pscustomobject]@{ Name = 'repository other' }) -OwnerName 'Gerber.B' -WarningVariable w -WarningAction SilentlyContinue).Count | Should -Be 1
        @($w).Count | Should -Be 0
    }

    It 'does not treat a plugin re-registering its own root as a conflict' {
        $builder = & $script:newBuilder @((& $script:owned 'ado' 'Gerber.A'))

        @(Resolve-GerberPluginNamespaceConflict -RegistryBuilder $builder -CommandDefinitionList @([pscustomobject]@{ Name = 'ado' }) -OwnerName 'Gerber.A').Count | Should -Be 1
    }

    It 'leaves roots owned by Core to the existing owner-conflict check' {
        $core = [pscustomobject]@{ Name = 'tools'; OwnerName = 'Gerber.Core'; OwnerType = 'Core' }
        $builder = & $script:newBuilder @($core)

        @(Resolve-GerberPluginNamespaceConflict -RegistryBuilder $builder -CommandDefinitionList @([pscustomobject]@{ Name = 'tools' }) -OwnerName 'Gerber.A').Count | Should -Be 1
        $builder.CommandList.Count | Should -Be 1
    }
}
