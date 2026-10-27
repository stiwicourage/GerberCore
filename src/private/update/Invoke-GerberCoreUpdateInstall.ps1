function Invoke-GerberCoreUpdateInstall {
    param([object]$State, [switch]$PassThru)
    try {
        Assert-GerberCoreInstallPlan $State
        $result = Install-PSModuleUpdate -Update $State.Plan -Confirm:$false `
            -TrustRepository:$State.Plan.RequiresRepositoryTrust -AcceptLicense:$State.Plan.RequiresLicenseAcceptance `
            -ErrorAction Stop -WarningAction SilentlyContinue -InformationAction SilentlyContinue -Verbose:$false -Debug:$false
        if ($PassThru) { return $result }
        return Format-GerberCoreUpdateResult $result
    } catch [System.Management.Automation.PipelineStoppedException] { throw
    } catch [System.OperationCanceledException] { throw
    } catch {
        return Get-GerberUpdateFailureMessage $_
    }
}

function Assert-GerberCoreInstallPlan {
    param([object]$State)
    $policy = Resolve-GerberCoreUpdatePolicy
    if ($State.Channel -cne $policy.Channel) {
        throw [System.InvalidOperationException]::new('Core update policy changed. Run /update list again for a fresh plan.')
    }
    $expected = @{
        ModuleName = 'Gerber'; RepositoryName = 'PSGallery'; RepositoryUri = 'https://www.powershellgallery.com/api/v2'
        Channel = $policy.Channel; Scope = $policy.Scope
    }
    foreach ($key in $expected.Keys) {
        if ([string]$State.Plan.$key -cne $expected[$key]) {
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
    if (-not $outcome) { return 'PMU returned an unknown installation outcome. Inspect the selected installation before retrying /update list.' }
    $text = "$outcome. Verification: $($Result.VerificationStatus). Recovery: $($Result.RecoveryStatus)."
    if ($Result.RestartRequired) { $text += ' Restart PowerShell before using Gerber again; this session has not reloaded Core.' }
    $text
}
