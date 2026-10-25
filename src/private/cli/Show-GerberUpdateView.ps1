function Show-GerberUpdateView {
    param()
    Start-GerberScreen -Name '/update'
    Write-GerberScreenLine -Text 'Checking Core updates...'
    $interactive = Test-GerberUpdateInteractive
    $state = Get-GerberCoreUpdateState
    Show-GerberCoreUpdateSummary -State $state
    Write-GerberPromptTrace -EventName 'update-discovery' -Data @{ Status = $state.Status }
    if (-not $interactive) { return }
    if ($state.Status -eq 'Available') { Invoke-GerberUpdateConfirmation $state }
    Wait-GerberContinue
}

function Invoke-GerberUpdateConfirmation {
    param([object]$State)
    $text = Get-GerberUpdateConsentText $State
    $options = Get-GerberConfirmationPromptOptionSet -ActionLabel 'Install Core update' -CancelLabel 'Cancel' -DefaultOption 'cancel'
    $accepted = Read-GerberConfirmationPrompt -Prompt 'Install Core update?' -ScreenTitle '/update' -ScreenText $text -PromptOptionSet $options
    Write-GerberScreenLine
    Write-GerberPromptTrace -EventName 'update-confirmation' -Data @{ Accepted = $accepted }
    if (-not $accepted) {
        Write-GerberScreenLine -Text 'Core update cancelled. Nothing was installed.'
        return
    }
    Write-GerberScreenLine -Text 'Installing Core update...'
    Write-GerberScreenLine -Text (Invoke-GerberCoreUpdateInstall -State $State)
    Write-GerberPromptTrace -EventName 'update-install-complete' -Data @{ Component = 'Core' }
}

function Get-GerberUpdateConsentText {
    param([object]$State)
    $text = (Format-GerberCoreUpdateOverview $State) + "`nScope: $($State.Plan.Scope)."
    if ($State.Plan.RequiresRepositoryTrust) { $text += ' Installing grants trust to this repository for this operation only.' }
    if ($State.Plan.RequiresLicenseAcceptance) { $text += ' Installing accepts the package license for this operation.' }
    $text + ' Gerber will not hot reload Core. Cancel is the default.'
}
