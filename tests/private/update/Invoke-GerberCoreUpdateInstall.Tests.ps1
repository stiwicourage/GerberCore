BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    . "$root/src/private/update/Invoke-GerberCoreUpdateInstall.ps1"
    . "$root/src/private/update/Get-GerberUpdateFailureMessage.ps1"
    . "$root/src/private/config/Get-GerberUserConfiguration.ps1"
    foreach ($name in @('Resolve-GerberCoreUpdatePolicy', 'Resolve-GerberUserConfigPath',
        'Test-GerberCoreUpdateConfiguration', 'Test-GerberUserConfiguration')) {
        . "$root/src/private/config/$name.ps1"
    }
    Import-Module PSModuleUpdate
}

Describe 'Invoke-GerberCoreUpdateInstall' -Tag 'G4A7' {
    BeforeEach {
        $script:state = [pscustomobject]@{
            Channel = 'Stable'
            Plan = [pscustomobject]@{
                RequiresRepositoryTrust = $true; RequiresLicenseAcceptance = $true
                ModuleName = 'Gerber'; RepositoryName = 'PSGallery'; RepositoryUri = 'https://www.powershellgallery.com/api/v2'
                Channel = 'Stable'; Scope = 'CurrentUser'
            }
            Credential = [pscredential]::new('user', [System.Security.SecureString]::new())
        }
        Mock Install-PSModuleUpdate {
            [pscustomobject]@{ Outcome = 'Installed'; VerificationStatus = 'Verified'; RestartRequired = $true; RecoveryStatus = 'NotRequired' }
        }
        Mock Get-GerberUserConfiguration { @{ schemaVersion = 1 } }
    }

    Context 'PMU installation boundary' {
        It 'accepts an original prerelease plan only while its discovered channel is still selected' {
            Mock Get-GerberUserConfiguration { @{ schemaVersion = 1; coreUpdates = @{ channel = 'IncludePrerelease' } } }
            $script:state.Channel = 'IncludePrerelease'
            $script:state.Plan.Channel = 'IncludePrerelease'
            Invoke-GerberCoreUpdateInstall -State $script:state | Should -Match 'Installed.*Restart PowerShell'
            Should -Invoke Install-PSModuleUpdate -Times 1
        }

        It 'requires rediscovery when configuration changes after discovery' {
            Mock Get-GerberUserConfiguration { @{ schemaVersion = 1; coreUpdates = @{ channel = 'IncludePrerelease' } } }
            Invoke-GerberCoreUpdateInstall -State $script:state | Should -Match 'fresh plan|/update'
            Should -Invoke Install-PSModuleUpdate -Times 0
        }

        It 'passes the actual live official plan without credentials and with explicitly confirmed consents' {
            Invoke-GerberCoreUpdateInstall -State $script:state | Should -Match 'Installed.*Restart PowerShell'
            Should -Invoke Install-PSModuleUpdate -Times 1 -ParameterFilter {
                [object]::ReferenceEquals($Update, $script:state.Plan) -and
                $null -eq $Credential -and
                $TrustRepository -and $AcceptLicense -and -not $Confirm
            }
        }

        It 'rejects a drifted <field> without installation' -ForEach @(
            @{ field = 'RepositoryName'; value = 'OtherFeed' }
            @{ field = 'RepositoryUri'; value = 'https://feed.invalid' }
            @{ field = 'ModuleName'; value = 'Gerber.Plugin' }
            @{ field = 'Channel'; value = 'IncludePrerelease' }
            @{ field = 'Scope'; value = 'AllUsers' }
        ) {
            $script:state.Plan.$field = $value
            Invoke-GerberCoreUpdateInstall -State $script:state | Should -Match 'fresh plan|/update'
            Should -Invoke Install-PSModuleUpdate -Times 0
        }

        It 'shows truthful cancelled and already-installed outcomes' -ForEach @('Cancelled', 'AlreadyInstalled') {
            $outcome = $_
            Mock Install-PSModuleUpdate {
                [pscustomobject]@{ Outcome = $outcome; VerificationStatus = 'Verified'; RestartRequired = $false; RecoveryStatus = 'Completed' }
            }
            Invoke-GerberCoreUpdateInstall -State $script:state | Should -Match $outcome
        }

        It 'never claims installation succeeded after an install or rollback failure' -ForEach @(
            @{ errorId = 'PMU.InstallationFailed'; text = 'failed' },
            @{ errorId = 'PMU.RollbackFailed'; text = 'rollback.*recovery' },
            @{ errorId = 'PMU.RecoveryRequired'; text = 'recovery' },
            @{ errorId = 'PMU.PlanStale'; text = '/update' }
        ) {
            Mock Install-PSModuleUpdate { Write-Error -Message 'raw-token-secret' -ErrorId $errorId -ErrorAction Stop }
            $textResult = Invoke-GerberCoreUpdateInstall -State $script:state
            $textResult | Should -Match $text
            $textResult | Should -Not -Match 'raw-token-secret|Installed and verified'
        }

        It 'propagates Ctrl+C rather than translating it to an installation failure' {
            $pipeline = [powershell]::Create()
            try {
                $null = $pipeline.AddScript({
                    param($root, $state)
                    . "$root/src/private/update/Invoke-GerberCoreUpdateInstall.ps1"
                    function Resolve-GerberCoreUpdatePolicy { @{ Channel = 'Stable'; Scope = 'CurrentUser' } }
                    function Install-PSModuleUpdate { throw [System.Management.Automation.PipelineStoppedException]::new() }
                    Invoke-GerberCoreUpdateInstall -State $state
                }).AddArgument($root).AddArgument($script:state)
                @($pipeline.Invoke()).Count | Should -Be 0
                $pipeline.InvocationStateInfo.State | Should -Be 'Stopped'
                $pipeline.InvocationStateInfo.Reason | Should -BeOfType ([System.Management.Automation.PipelineStoppedException])
            } finally { $pipeline.Dispose() }
        }
    }
}
