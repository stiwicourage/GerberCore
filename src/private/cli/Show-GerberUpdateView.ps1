function Show-GerberUpdateView {
    param()
    Start-GerberScreen -Name '/update list'
    Write-GerberScreenLine -Text 'Checking Core updates...'
    $interactive = Test-GerberUpdateInteractive
    $state = Get-GerberCoreUpdateState
    Show-GerberCoreUpdateSummary -State $state
    Write-GerberPromptTrace -EventName 'update-discovery' -Data @{ Status = $state.Status }
    if (-not $interactive) { return }
    $restartText = if ($state.Status -eq 'Available') { Invoke-GerberUpdateConfirmation $state
    } elseif ($state.Status -eq 'RestartRequired') { $state.Message }
    if ($restartText) { return Show-GerberCoreUpdateRestartChoice -Text $restartText }
    Wait-GerberContinue
}

function Invoke-GerberUpdateConfirmation {
    param([object]$State)
    $text = Get-GerberUpdateConsentText $State
    $options = Get-GerberConfirmationPromptOptionSet -ActionLabel 'Install Core update' -CancelLabel 'Cancel' -DefaultOption 'cancel'
    $accepted = Read-GerberConfirmationPrompt -Prompt 'Install Core update?' -ScreenTitle '/update list' -ScreenText $text -PromptOptionSet $options
    Write-GerberScreenLine
    Write-GerberPromptTrace -EventName 'update-confirmation' -Data @{ Accepted = $accepted }
    if (-not $accepted) {
        Write-GerberScreenLine -Text 'Core update cancelled. Nothing was installed.'
        return
    }
    Write-GerberScreenLine -Text 'Installing Core update...'
    Complete-GerberUpdateInstallation -State $State
}

function Complete-GerberUpdateInstallation {
    param([object]$State)
    $result = Invoke-GerberCoreUpdateInstall -State $State -PassThru
    $text = if ($result -is [string]) { $result } else { Format-GerberCoreUpdateResult $result }
    Write-GerberScreenLine -Text $text
    Write-GerberPromptTrace -EventName 'update-install-complete' -Data @{ Component = 'Core' }
    if (Test-GerberUpdateRestartRequired -Result $result) { return $text }
}

function Test-GerberUpdateRestartRequired {
    param([object]$Result)
    if ($Result -is [string]) { return $false }
    if ($Result.Outcome -notin @('Installed', 'AlreadyInstalled')) { return $false }
    return $Result.VerificationStatus -eq 'Verified' -and $Result.RestartRequired
}

function Get-GerberUpdateConsentText {
    param([object]$State)
    $text = (Format-GerberCoreUpdateOverview $State) + "`nScope: $($State.Plan.Scope)."
    if ($State.Plan.RequiresRepositoryTrust) { $text += ' Installing grants trust to this repository for this operation only.' }
    if ($State.Plan.RequiresLicenseAcceptance) { $text += ' Installing accepts the package license for this operation.' }
    $text + ' Gerber will not hot reload Core. Cancel is the default.'
}
