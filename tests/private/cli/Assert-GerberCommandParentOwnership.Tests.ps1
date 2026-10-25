BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    . (Join-Path $root 'src/private/cli/Assert-GerberCommandParentOwnership.ps1')
}

Describe 'Assert-GerberCommandParentOwnership' -Tag 'PluginTransactions' {
    Context 'Allowed parent boundaries' {
        It 'allows <Case> parents' -ForEach @(
            @{ Case = 'missing'; Parent = $null },
            @{ Case = 'Core'; Parent = [pscustomobject]@{ Name = 'repository'; OwnerType = 'Core'; OwnerName = 'Gerber.Core' } },
            @{ Case = 'same-plugin'; Parent = [pscustomobject]@{ Name = 'repository shared'; OwnerType = 'Plugin'; OwnerName = 'GERBER.A' } }
        ) {
            $command = [pscustomobject]@{ Name = 'repository shared child'; OwnerName = 'Gerber.A' }

            { Assert-GerberCommandParentOwnership -Parent $Parent -Command $command } | Should -Not -Throw
        }
    }

    Context 'Forbidden plugin dependencies' {
        It 'reports the command and parent owner for a different plugin parent' {
            $parent = [pscustomobject]@{ Name = 'repository shared'; OwnerType = 'Plugin'; OwnerName = 'Gerber.B' }
            $command = [pscustomobject]@{ Name = 'repository shared child'; OwnerName = 'Gerber.A' }

            { Assert-GerberCommandParentOwnership -Parent $parent -Command $command } |
                Should -Throw '*repository shared child*parent*Gerber.B*'
        }
    }
}
