function Confirm-GerberPluginDevelopmentTool {
    if (@(Get-Module -Name NovaModuleTools -ListAvailable).Count -gt 0) {
        return $true
    }
    if (-not (Read-GerberPluginToolInstallationConsent)) {
        Write-GerberScreenLine -Text 'Plugin creation cancelled. No project or approval was created.'
        return $false
    }

    Install-Module -Name NovaModuleTools -ErrorAction Stop
    if (@(Get-Module -Name NovaModuleTools -ListAvailable).Count -eq 0) {
        throw [System.InvalidOperationException]::new('NovaModuleTools is still unavailable. Install-Module -Name NovaModuleTools, then retry /plugins create.')
    }
    return $true
}

function Read-GerberPluginToolInstallationConsent {
    $options = Get-GerberConfirmationPromptOptionSet -ActionLabel 'Install' -CancelLabel 'Cancel' -DefaultOption 'cancel'
    return Read-GerberConfirmationPrompt -ScreenTitle '/plugins create' `
        -ScreenText 'Plugin development needs NovaModuleTools. Install it with Install-Module -Name NovaModuleTools?' `
        -Prompt 'Install NovaModuleTools?' -PromptOptionSet $options
}
