BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Resolve-GerberCoreUpdatePolicy' -Tag 'CoreUpdatePolicy' {
    Context 'validated channel and fixed repository safeguards' {
        It 'defaults to Stable without persisting missing configuration' {
            Mock Get-GerberUserConfiguration { @{ schemaVersion = 1 } }
            Mock Save-GerberUserConfiguration {}
            $policy = Resolve-GerberCoreUpdatePolicy
            $policy.Channel | Should -BeExactly 'Stable'
            $policy.Scope | Should -BeExactly 'CurrentUser'
            $policy.ExpectedRepositoryUri.AbsoluteUri | Should -BeExactly 'https://www.powershellgallery.com/api/v2'
            Should -Invoke Save-GerberUserConfiguration -Times 0
        }

        It 'reads <channel> while ignoring legacy repository and policy overrides' -ForEach @('Stable', 'IncludePrerelease') {
            $channel = $_
            Mock Get-GerberUserConfiguration {
                @{ schemaVersion = 1; coreUpdates = @{ channel = $channel }
                    updates = @{ modules = @{ Gerber = @{ repository = 'OtherFeed'; policy = @{ Scope = 'AllUsers' } } } } }
            }
            $policy = Resolve-GerberCoreUpdatePolicy
            $policy.Channel | Should -BeExactly $channel
            $policy.Scope | Should -BeExactly 'CurrentUser'
            $policy.ExpectedRepositoryUri.Host | Should -BeExactly 'www.powershellgallery.com'
        }
    }
}
