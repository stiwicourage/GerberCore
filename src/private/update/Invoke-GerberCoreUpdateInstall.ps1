function Invoke-GerberCoreUpdateInstall {
    param([object]$State)
    try {
        Assert-GerberCoreInstallPlan $State.Plan
        $result = Install-PSModuleUpdate -Update $State.Plan -Confirm:$false `
            -TrustRepository:$State.Plan.RequiresRepositoryTrust -AcceptLicense:$State.Plan.RequiresLicenseAcceptance `
            -ErrorAction Stop -WarningAction SilentlyContinue -InformationAction SilentlyContinue -Verbose:$false -Debug:$false
        return Format-GerberCoreUpdateResult $result
    } catch [System.Management.Automation.PipelineStoppedException] { throw
    } catch [System.OperationCanceledException] { throw
    } catch {
        return Get-GerberUpdateFailureMessage $_
    }
}

function Assert-GerberCoreInstallPlan {
    param([object]$Plan)
    $expected = @{
        ModuleName = 'Gerber'; RepositoryName = 'PSGallery'; RepositoryUri = 'https://www.powershellgallery.com/api/v2'
        Channel = 'Stable'; Scope = 'CurrentUser'
    }
    foreach ($key in $expected.Keys) {
        if ([string]$Plan.$key -cne $expected[$key]) {
            throw [System.InvalidOperationException]::new('Core installation requires a fresh official update plan.')
        }
    }
}

function Format-GerberCoreUpdateResult {
    param([object]$Result)
    $messages = @{
        Installed = 'Installed'
        AlreadyInstalled = 'AlreadyInstalled'
        Cancelled = 'Cancelled'
        WhatIf = 'WhatIf (no installation)'
    }
    $outcome = $messages[$Result.Outcome]
    if (-not $outcome) { return 'PMU returned an unknown installation outcome. Inspect the selected installation before retrying /update.' }
    $text = "$outcome. Verification: $($Result.VerificationStatus). Recovery: $($Result.RecoveryStatus)."
    if ($Result.RestartRequired) { $text += ' Restart PowerShell before using Gerber again; this session has not reloaded Core.' }
    $text
}
