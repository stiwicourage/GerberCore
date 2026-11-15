function Invoke-GerberPluginsInstallCommand {
    [CmdletBinding()]
    param(
        [pscustomobject]$Command = [pscustomobject]@{ Arguments = @() }
    )

    Assert-GerberPluginsActivationCommandInput -Command $Command -CommandName 'install'
    $name = Read-GerberPluginInstallName
    if ([string]::IsNullOrEmpty($name)) {
        return
    }

    $verdict = Get-GerberGalleryNamespaceVerdict -Name $name
    if ($verdict.Status -eq 'Conflict') {
        Show-GerberTextBlock -Title '/plugins install' -Text (Get-GerberPluginInstallConflictText -Name $name -Verdict $verdict)
        Wait-GerberContinue
        return
    }

    if (-not (Confirm-GerberPluginInstall -Name $name -Verdict $verdict)) {
        return
    }

    Show-GerberTextBlock -Title '/plugins install' -Text (Install-GerberPluginWithResultText -Name $name)
    Wait-GerberContinue
}

function Read-GerberPluginInstallName {
    Write-GerberScreenLine -Text 'Enter the PowerShell Gallery module name of the plugin to install. Esc goes back.'
    while ($true) {
        try {
            $name = [string](Read-GerberCommand -Prompt 'Plugin module name' -SuggestionMode 'None' -TrimResult $true)
        } catch {
            if (Test-GerberMenuEscapeException -Exception $_.Exception) {
                return $null
            }
            throw
        }

        if ([string]::IsNullOrEmpty($name) -or $name -match '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
            return $name
        }
        Show-GerberTextBlock -Title '/plugins install' -Text "'$name' is not a valid module name."
    }
}

function Get-GerberPluginInstallConflictText {
    param([string]$Name, [pscustomobject]$Verdict)

    return "Gerber will not install '$Name'. Namespace '/$($Verdict.Namespace)' belongs to " +
        "'$($Verdict.Owner.Name)', which was first published on PowerShell Gallery on " +
        "$($Verdict.Owner.FirstPublished.ToString('yyyy-MM-dd'))."
}

function Confirm-GerberPluginInstall {
    [OutputType([bool])]
    param([string]$Name, [pscustomobject]$Verdict)

    $screenText = if ($Verdict.Status -eq 'Unverified') {
        "The namespace of '$Name' is unverified: $($Verdict.Reason)`nInstall it without the registry check?"
    } else {
        "Install '$Name' from PowerShell Gallery for the current user?"
    }

    return Read-GerberConfirmationPrompt -Prompt 'Install plugin' -ScreenTitle '/plugins install' -ScreenText $screenText `
        -PromptOptionSet (Get-GerberConfirmationPromptOptionSet -ActionLabel 'Install' -DefaultOption 'cancel')
}

function Install-GerberPluginWithResultText {
    [OutputType([string])]
    param([string]$Name)

    try {
        Install-GerberGalleryPlugin -Name $Name
    } catch {
        return "Gerber could not install '$Name': $($_.Exception.Message)"
    }

    return "Installed '$Name'. Run /plugins enable to review and approve it."
}
