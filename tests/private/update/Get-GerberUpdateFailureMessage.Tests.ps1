BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    . "$root/src/private/update/Get-GerberUpdateFailureMessage.ps1"
}

Describe 'Get-GerberUpdateFailureMessage' -Tag 'G4A7' {
    Context 'safe actionable PMU diagnostics' {
        It 'maps <id> to supported-layout guidance without guessing the cause or recovery outcome' -Tag 'UnsupportedInstallation' -ForEach @(
            @{ id = 'PMU.UnsupportedInstallation'; detail = 'raw-layout: no version directories user:secret' }
            @{ id = 'PMU.UnsupportedInstallation,Get-PSModuleUpdate'; detail = 'raw-layout: another unsupported case user:secret' }
        ) {
            $record = [System.Management.Automation.ErrorRecord]::new(
                [System.InvalidOperationException]::new($detail),
                $id, [System.Management.Automation.ErrorCategory]::NotSpecified, $null
            )
            $message = Get-GerberUpdateFailureMessage -ErrorRecord $record
            $message | Should -Match 'current installation layout.*supported numeric-version module directory.*restart PowerShell.*retry /update'
            $message | Should -Match 'No success or rollback is assumed'
            $message | Should -Not -Match 'PSGallery|connection|flat-only|raw-layout|user:secret|No files were changed'
        }

        It 'uses error identifiers only, never credential-bearing provider text' -ForEach @(
            @{ id = 'PMU.PackageNotFound'; expected = 'No eligible.*PSGallery' },
            @{ id = 'PMU.RollbackFailed,Install-PSModuleUpdate'; expected = 'rollback.*recovery' },
            @{ id = 'PMU.RecoveryRequired'; expected = 'recovery' },
            @{ id = 'PMU.PlanStale'; expected = '/update' },
            @{ id = 'PMU.InstallationFailed'; expected = 'failed' },
            @{ id = 'Unknown'; expected = 'repository|connection' }
        ) {
            $record = [System.Management.Automation.ErrorRecord]::new(
                [System.InvalidOperationException]::new('https://user:secret@feed.invalid'),
                $id, [System.Management.Automation.ErrorCategory]::NotSpecified, $null
            )
            $message = Get-GerberUpdateFailureMessage -ErrorRecord $record
            $message | Should -Match $expected
            $message | Should -Not -Match 'user:secret|feed.invalid'
        }
    }
}
