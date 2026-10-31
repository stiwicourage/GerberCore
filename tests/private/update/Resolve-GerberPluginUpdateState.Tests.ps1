BeforeAll {
    Import-Module PSModuleUpdate -RequiredVersion 0.2.0
    . (Join-Path $PSScriptRoot '../../TestHelpers/PluginUpdate.TestSupport.ps1')
    . (Join-Path $PSScriptRoot '../../TestHelpers/UpdateActivation.TestSupport.ps1')
    . (Join-Path $PSScriptRoot '../../../src/private/shared/ConvertTo-GerberPluginRepositoryUri.ps1')
}

Describe 'Resolve-GerberPluginUpdateState' -Tag 'G4A9' {
    Context 'public PMU discovery' {
        BeforeEach {
            $fixture = Initialize-TestActivationFixture (Join-Path $TestDrive 'discovery') @{
                Plugin               = $true
                ApiVersion           = '1'
                MinimumGerberVersion = '0.2.0'
            }
            $manifest = Get-Content -LiteralPath $fixture.Path -Raw
            $manifest = $manifest.Replace('MinimumGerberVersion =', "RepositoryUri = 'https://packages.example.org/v3/index.json'`n    MinimumGerberVersion =")
            Set-Content -LiteralPath $fixture.Path -Value $manifest
            $script:entry = Get-TestPluginUpdateEntry $fixture.Name
            $script:entry.ModulePath = $fixture.Path
            $script:module = @(Get-Module -ListAvailable -Name $fixture.Path)[0]
            $script:module.PrivateData.Gerber.RepositoryUri = 'https://packages.example.org/v3/index.json'
            $olderPath = Join-Path $TestDrive 'Gerber.ActivationFixture.psd1'
            New-ModuleManifest -Path $olderPath -ModuleVersion '0.5.0' -Guid $fixture.Guid
            $script:older = @(Get-Module -ListAvailable -Name $olderPath)[0]
            Mock Get-Module {
                $script:module
            } -ParameterFilter {
                $ListAvailable
            }
            Mock Get-Module {
                @()
            } -ParameterFilter {
                -not $ListAvailable
            }
            Mock Resolve-GerberPluginUpdateScope {
                'AllUsers'
            }
            Mock Resolve-GerberCoreUpdatePolicy {
                @{
                    Channel = 'IncludePrerelease'
                    Scope   = 'CurrentUser'
                }
            }
            Mock Get-PSModuleUpdate {
                $plan = Get-TestPluginUpdatePlan $script:entry.Name
                $plan.Scope = 'AllUsers'
                $plan.Channel = 'IncludePrerelease'
                $plan
            }
        }

        It 'forwards the declared source, shared channel, preserved scope and operation-owned credentials' {
            $script:fixtureCredential = [pscredential]::new('fixture-user', [securestring]::new())
            $item = Resolve-GerberPluginUpdateState $script:entry $script:fixtureCredential
            $item.State.Status | Should -Be 'Available'
            $item.State.Repository | Should -Be 'https://packages.example.org/v3/index.json'
            Should -Invoke Get-PSModuleUpdate -Times 1 -ParameterFilter {
                [object]::ReferenceEquals($Credential, $script:fixtureCredential) -and
                $RepositoryUri.AbsoluteUri -eq 'https://packages.example.org/v3/index.json' -and
                $Policy.Channel -eq 'IncludePrerelease' -and $Policy.Scope -eq 'AllUsers'
            }
        }

        It 'classifies public authentication failures without fallback or provider diagnostics' {
            Mock Get-PSModuleUpdate {
                Write-Error 'private-feed-diagnostic' -ErrorId 'PMU.AuthenticationFailed' -ErrorAction Stop
            }
            $item = Resolve-GerberPluginUpdateState $script:entry
            $item.State.Status | Should -Be 'CredentialRequired'
            $item.State.Plan | Should -BeNullOrEmpty
            $item.State.Message | Should -Not -Match 'private-feed-diagnostic'
            Should -Invoke Get-PSModuleUpdate -Times 1
        }

        It 'gives PMU the loaded version while preserving the selected installation scope and source' {
            Mock Get-Module {
                $script:older
            } -ParameterFilter {
                -not $ListAvailable
            }
            $item = Resolve-GerberPluginUpdateState $script:entry
            $item.State.Status | Should -Be 'Available'
            Should -Invoke Get-PSModuleUpdate -Times 1 -ParameterFilter {
                [object]::ReferenceEquals($Module, $script:older) -and
                $Policy.Scope -eq 'AllUsers' -and
                $RepositoryUri.AbsoluteUri -eq 'https://packages.example.org/v3/index.json'
            }
        }

        It 'reads current installed metadata when cached module information predates the plugin manifest' {
            Mock Get-Module {
                $script:older
            } -ParameterFilter {
                $ListAvailable
            }
            $item = Resolve-GerberPluginUpdateState $script:entry
            $item.State.Status | Should -Be 'Available'
            $item.State.Repository | Should -Be 'https://packages.example.org/v3/index.json'
        }

        It 'rejects a changed manifest GUID even when cached module identity still matches' {
            $manifest = Get-Content -LiteralPath $script:entry.ModulePath -Raw
            Set-Content -LiteralPath $script:entry.ModulePath -Value $manifest.Replace($script:entry.Guid, [guid]::NewGuid().ToString())
            $item = Resolve-GerberPluginUpdateState $script:entry
            $item.State.Status | Should -Be 'Unavailable'
            Should -Invoke Get-PSModuleUpdate -Times 0
        }

        It 'rejects a current invalid override instead of using a cached valid source or Gallery' {
            $manifest = Get-Content -LiteralPath $script:entry.ModulePath -Raw
            Set-Content -LiteralPath $script:entry.ModulePath -Value $manifest.Replace('https://packages.example.org/v3/index.json', 'relative-feed')
            $item = Resolve-GerberPluginUpdateState $script:entry
            $item.State.Status | Should -Be 'Unavailable'
            Should -Invoke Get-PSModuleUpdate -Times 0
        }

        It 'rejects the creation placeholder without package lookup or Gallery fallback' -Tag 'PluginCreateRepository' {
            $manifest = Get-Content -LiteralPath $script:entry.ModulePath -Raw
            Set-Content -LiteralPath $script:entry.ModulePath -Value $manifest.Replace('https://packages.example.org/v3/index.json', 'REPLACE_WITH_REPOSITORY_URI')
            $item = Resolve-GerberPluginUpdateState $script:entry
            $item.State.Status | Should -Be 'Unavailable'
            $item.State.Plan | Should -BeNullOrEmpty
            Should -Invoke Get-PSModuleUpdate -Times 0
        }

        It 'rejects changed installed identity before making a package lookup' {
            $script:entry.Guid = [guid]::NewGuid().ToString()
            $item = Resolve-GerberPluginUpdateState $script:entry
            $item.State.Status | Should -Be 'Unavailable'
            Should -Invoke Get-PSModuleUpdate -Times 0
        }
    }

    Context 'plugin-author repository metadata' -Tag 'PluginCreateUriCharacterization' {
        It 'defaults only an absent override to the official Gallery endpoint' {
            $uri = Resolve-GerberPluginRepositoryUri @{
                Gerber = @{
                    Plugin = $true
                }
            }
            $uri.AbsoluteUri | Should -BeExactly 'https://www.powershellgallery.com/api/v2'
        }

        It 'reads RepositoryUri directly under Gerber, without an Update intermediary' {
            $uri = Resolve-GerberPluginRepositoryUri @{
                Gerber = @{
                    RepositoryUri = 'https://packages.example.org/v3/index.json'
                }
            }
            $uri.AbsoluteUri | Should -BeExactly 'https://packages.example.org/v3/index.json'
        }

        It 'rejects invalid declared overrides instead of falling back' -ForEach @(
            '', 'relative/path', 'https://user:password@example.org/feed',
            'https://example.org/feed?token=secret', 'https://example.org/feed#fragment', $null,
            'REPLACE_WITH_REPOSITORY_URI'
        ) {
            $value = $_
            {
                Resolve-GerberPluginRepositoryUri @{
                    Gerber = @{
                        RepositoryUri = $value
                    }
                }
            } | Should -Throw
        }
    }
}
