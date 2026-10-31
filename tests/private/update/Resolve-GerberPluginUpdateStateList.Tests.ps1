BeforeAll {
    . (Join-Path $PSScriptRoot '../../TestHelpers/PluginUpdate.TestSupport.ps1')
}

Describe 'Resolve-GerberPluginUpdateStateList' -Tag 'G4A9' {
    BeforeEach {
        $script:entry = Get-TestPluginUpdateEntry
        Mock Get-GerberPluginInventory {
            @($script:entry)
        }
    }

    It 'excludes disabled, unapproved, unassociated and missing plugins without provider access' -ForEach @(
        @{
            field = 'IsEnabled'
            value = $false
        }
        @{
            field = 'IsAssociated'
            value = $false
        }
        @{
            field = 'IsDiscovered'
            value = $false
        }
        @{
            field = 'ApprovalStatus'
            value = 'Unknown'
        }
        @{
            field = 'ApprovalStatus'
            value = 'Declined'
        }
    ) {
        $script:entry.$field = $value
        Mock Get-PSModuleUpdate {
            throw 'Provider must not run for an ineligible plugin.'
        }
        @(Resolve-GerberPluginUpdateStateList).Count | Should -Be 0
        Should -Invoke Get-PSModuleUpdate -Times 0
    }
}
