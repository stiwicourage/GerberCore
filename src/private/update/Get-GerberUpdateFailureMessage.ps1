function Get-GerberUpdateFailureMessage {
    param([System.Management.Automation.ErrorRecord]$ErrorRecord)
    $id = ($ErrorRecord.FullyQualifiedErrorId -split ',')[0]
    $messages = @{
        'PMU.PackageNotFound' = 'No eligible Gerber package is available from PSGallery under the stable update policy. Run /update to check again later.'
        'PMU.RollbackFailed' = 'Installation and rollback failed. Preserve PMU journals and backups for recovery; inspect the selected installation before retrying /update.'
        'PMU.RecoveryRequired' = 'PMU recovery is required. Preserve journals and backups; inspect the selected installation before retrying /update.'
        'PMU.RepositoryRecoveryRequired' = 'PMU repository recovery is required. Preserve repository receipts; inspect the configured registration before retrying /update.'
        'PMU.InstallationFailed' = 'Installation failed. Do not assume success or rollback; inspect the selected installation and obtain a fresh plan with /update.'
        'PMU.PlanStale' = 'The update plan is no longer current. Run /update again for a fresh plan.'
        'PMU.PermissionDenied' = 'The CurrentUser update scope is not writable. Check permissions, then retry /update.'
    }
    if ($messages.ContainsKey($id)) { return $messages[$id] }
    return 'Update unavailable or installation failed. Check the PSGallery repository registration and connection, then retry /update. No success or rollback is assumed.'
}
