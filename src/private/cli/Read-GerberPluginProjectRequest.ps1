function Read-GerberPluginProjectRequest {
    $fields = [ordered]@{
        Suffix = 'Module suffix (fixed Gerber. prefix)'
        Description = 'Description'
        Namespace = 'Command namespace'
        ParentPath = 'Destination parent'
    }
    $answers = @{}
    foreach ($field in $fields.Keys) {
        Show-GerberPluginProjectField -Field $field -Suffix $answers['Suffix']
        $answers[$field] = Read-GerberPluginProjectField -Field $field -Prompt $fields[$field]
    }
    return Resolve-GerberPluginProjectRequest @answers
}

function Show-GerberPluginProjectField {
    param([string]$Field, [string]$Suffix)

    Write-GerberScreenLine -Text ''
    foreach ($line in (Get-GerberPluginProjectFieldLineList -Field $Field -Suffix $Suffix)) {
        Write-GerberScreenLine -Text $line
    }
    Write-GerberScreenLine -Text ''
}

function Get-GerberPluginProjectFieldLineList {
    param([string]$Field, [string]$Suffix)

    $guidance = @{
        Suffix = @('Plugin Name', 'Enter the name of your plugin. Gerber automatically adds the "Gerber." prefix.', 'Example: Gerber.MyCompany (enter MyCompany)')
        Description = @('Description', 'Briefly describe the purpose of your plugin.', 'Example: Local development tools')
        Namespace = @('Command Namespace', 'Commands provided by your plugin will be registered under this namespace.', 'Example: mycompany registers /mycompany hello')
        ParentPath = @('Destination', 'Select the parent directory for your project. Press Enter to use the current working directory.', "Default: $((Get-Location).ProviderPath)", "Project directory: $(Join-Path (Get-Location).ProviderPath "Gerber.$Suffix")")
    }
    $lines = $guidance[$Field]
    return @($lines[0]; ([string][char]0x2500) * 51; $lines[1..($lines.Count - 1)])
}

function Read-GerberPluginProjectField {
    param([string]$Field, [string]$Prompt)

    while ($true) {
        $value = Read-GerberCommand -Prompt $Prompt -SuggestionMode 'None' -TrimResult $true
        if ($Field -eq 'ParentPath' -and [string]::IsNullOrWhiteSpace($value)) {
            $value = (Get-Location).ProviderPath
        }
        if (Test-GerberPluginProjectFieldInput -Field $Field -Value $value) {
            return $value
        }
    }
}

function Test-GerberPluginProjectFieldInput {
    param([string]$Field, [string]$Value)

    try {
        Assert-GerberPluginProjectInput -Field $Field -Value $Value
        return $true
    } catch [System.ArgumentException] {
        Write-GerberPromptTrace -EventName 'plugin-create-input-rejected' -Data @{ Field = $Field }
        Write-GerberScreenLine -Text $_.Exception.Message
        return $false
    }
}
