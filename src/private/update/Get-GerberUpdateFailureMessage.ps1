function Get-GerberUpdateFailureMessage {
    param([System.Management.Automation.ErrorRecord]$ErrorRecord)
    $id = ($ErrorRecord.FullyQualifiedErrorId -split ',')[0]
    if ($id -ceq 'PMU.UnsupportedInstallation' -and
        $ErrorRecord.Exception.Message -ceq 'The selected installation has no native provider metadata.') {
        return 'Core installation has no native provider metadata and appears to have been locally copied or published. Reinstall the current Gerber version from PSGallery, restart PowerShell, then retry /update list. No success or rollback is assumed.'
    }
    $messages = @{
        'PMU.PackageNotFound' = 'No eligible Gerber package is available from PSGallery under the selected update policy. Run /update list to check again later.'
        'PMU.RollbackFailed' = 'Installation and rollback failed. Preserve PMU journals and backups for recovery; inspect the selected installation before retrying /update list.'
        'PMU.RecoveryRequired' = 'PMU recovery is required. Preserve journals and backups; inspect the selected installation before retrying /update list.'
        'PMU.RepositoryRecoveryRequired' = 'PMU repository recovery is required. Preserve repository receipts; inspect the configured registration before retrying /update list.'
        'PMU.InstallationFailed' = 'Installation failed. Do not assume success or rollback; inspect the selected installation and obtain a fresh plan with /update list.'
        'PMU.PlanStale' = 'The update plan is no longer current. Run /update list again for a fresh plan.'
        'PMU.PermissionDenied' = 'The CurrentUser update scope is not writable. Check permissions, then retry /update list.'
        'PMU.UnsupportedInstallation' = 'Core update discovery cannot use the current installation layout. Install Gerber in a supported numeric-version module directory, then restart PowerShell and retry /update list. No success or rollback is assumed.'
    }
    return $messages[$id] ?? 'Update unavailable or installation failed. Check the PSGallery repository registration and connection, then retry /update list. No success or rollback is assumed.'
}
