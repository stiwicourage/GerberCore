BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    . "$root/src/private/update/Get-GerberUpdateFailureMessage.ps1"
}

Describe 'Get-GerberUpdateFailureMessage' -Tag 'G4A7' {
    Context 'safe actionable PMU diagnostics' {
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
