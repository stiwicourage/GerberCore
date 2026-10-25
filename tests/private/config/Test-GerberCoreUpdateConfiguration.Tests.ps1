BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Test-GerberCoreUpdateConfiguration' -Tag 'CoreUpdatePolicy' {
    Context 'optional section with strict explicit values' {
        It 'accepts missing section or channel and both exact supported channels' -ForEach @(
            @{ configuration = @{ schemaVersion = 1 } }
            @{ configuration = @{ schemaVersion = 1; coreUpdates = @{} } }
            @{ configuration = @{ schemaVersion = 1; coreUpdates = @{ channel = 'Stable' } } }
            @{ configuration = [pscustomobject]@{ schemaVersion = 1; coreUpdates = [pscustomobject]@{ channel = 'IncludePrerelease' } } }
        ) {
            Test-GerberUserConfiguration $configuration '/tmp/policy-config.json' | Should -BeTrue
        }

        It 'rejects an explicit invalid section <value>' -ForEach @(
            @{ value = $null }, @{ value = 'Stable' }, @{ value = @() }, @{ value = 1 }, @{ value = $false },
            @{ value = @(@{ channel = 'Stable' }) }
        ) {
            { Test-GerberUserConfiguration @{ schemaVersion = 1; coreUpdates = $value } '/tmp/policy-config.json' } |
                Should -Throw '*coreUpdates*JSON object*'
        }

        It 'rejects an explicit invalid channel <value>' -ForEach @(
            @{ value = $null }, @{ value = '' }, @{ value = 'stable' }, @{ value = 'Preview' },
            @{ value = @('Stable') }, @{ value = @{} }, @{ value = 1 }, @{ value = $false }
        ) {
            { Test-GerberUserConfiguration @{ schemaVersion = 1; coreUpdates = @{ channel = $value } } '/tmp/policy-config.json' } |
                Should -Throw '*coreUpdates.channel*Stable*IncludePrerelease*'
        }
    }
}
