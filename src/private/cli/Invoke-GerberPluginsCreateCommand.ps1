function Invoke-GerberPluginsCreateCommand {
    param([pscustomobject]$Command = [pscustomobject]@{ Arguments = @() })

    Assert-GerberPluginsActivationCommandInput -Command $Command -CommandName 'create'
    if (-not (Confirm-GerberPluginDevelopmentTool)) {
        return
    }
    Start-GerberScreen -Name '/plugins create'
    Show-GerberTextBlock -Title 'Create Gerber Plugin' -Text @'
Create a new Gerber PowerShell plugin project.
Includes a working example command, tests, and NovaModuleTools integration.
Esc cancels without approval.
'@
    $result = Invoke-GerberPluginProjectCreationPrompt
    Show-GerberPluginProjectCreationSummary -Result $result
    Wait-GerberContinue
}

function Show-GerberPluginProjectCreationSummary {
    param([pscustomobject]$Result)

    $quotedPath = $Result.Path.Replace("'", "''")
    Show-GerberTextBlock -Title 'Gerber Plugin Created' -Text @"
Name:       $($Result.Name)
Version:    $($Result.Version)
Namespace:  /$($Result.Namespace)
Location:   $($Result.Path)
GUID: $($Result.Guid)

Approval:   Approved
Associated: Yes
Enabled:    Yes
Installed:  No

Next steps:
  cd '$quotedPath'
  Publish-NovaModule -Local

Restart Gerber after installation.
Example command:
  /$($Result.Namespace) hello
"@
}

function Invoke-GerberPluginProjectCreationPrompt {
    while ($true) {
        try {
            $request = Read-GerberPluginProjectRequest
            Write-GerberScreenLine -Text 'Generating and validating plugin (Nova build, unit tests, integration tests, Core registration)...'
            return New-GerberPluginProject -Request $request
        } catch [System.ArgumentException] {
            Write-GerberPromptTrace -EventName 'plugin-create-input-rejected' -Data @{ Field = 'Destination' }
            Write-GerberScreenLine -Text $_.Exception.Message
            Write-GerberScreenLine -Text 'Choose another module suffix or destination parent. Esc cancels.'
        }
    }
}
