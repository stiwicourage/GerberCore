function Test-GerberPluginProject {
    param([pscustomobject]$Request, [string]$Path, [string]$Guid)

    Write-GerberPromptTrace -EventName 'plugin-create-validation-started' -Data @{ Name = $Request.Name }
    Assert-GerberGeneratedSourceBoundary -Path $Path
    $validationScript = Join-Path (Get-GerberPluginTemplatePath) '../Test-GerberGeneratedProject.ps1'
    $output = & (Join-Path $PSHOME 'pwsh') -NoLogo -NoProfile -NonInteractive -File $validationScript -ProjectPath $Path 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw [System.IO.InvalidDataException]::new("Plugin validation failed. No project or approval was saved. $($output -join [Environment]::NewLine)")
    }
    Assert-GerberGeneratedPluginRegistration -Request $Request -Path $Path -Guid $Guid
    Write-GerberPromptTrace -EventName 'plugin-create-validation-passed' -Data @{ Name = $Request.Name; Guid = $Guid }
}

function Assert-GerberGeneratedSourceBoundary {
    param([string]$Path)

    $boundary = Test-GerberPluginBoundary -Path $Path
    if ($boundary.IsValid) {
        return
    }
    $details = $boundary.Diagnostics | ForEach-Object { "$($_.File):$($_.Line) $($_.Dependency): $($_.Reason). $($_.Resolution)" }
    throw [System.IO.InvalidDataException]::new("Plugin boundary validation failed. No project or approval was saved. $($details -join [Environment]::NewLine)")
}

function Assert-GerberGeneratedPluginRegistration {
    param([pscustomobject]$Request, [string]$Path, [string]$Guid)

    $plugin = @(Get-GerberDiscoveredPluginModuleList -PluginModulePathList @((Join-Path $Path 'dist')))[0]
    if ($plugin.Guid -ne $Guid -or $plugin.Name -ne $Request.Name) {
        throw [System.IO.InvalidDataException]::new('Generated plugin identity does not match its project.')
    }
    $builder = Get-GerberPluginValidationRegistry
    try {
        $state = [pscustomobject]@{ IsAssociated = $true; IsEnabled = $true }
        Add-GerberPluginToRegistryBuilder -RegistryBuilder $builder -PluginModule $plugin -LifecycleState $state
    } finally {
        Remove-Module -Name $Request.Name -Force -ErrorAction SilentlyContinue
    }
}

function Get-GerberPluginValidationRegistry {
    $state = [pscustomobject]@{
        CommandList = @(Get-GerberCommandRegistry)
        PluginList = @()
        GerberVersion = Get-GerberCurrentVersion
    }
    $copy = Copy-GerberCommandRegistryState -State $state
    $builder = [pscustomobject]@{
        CommandList = [System.Collections.Generic.List[object]]::new()
        PluginList = [System.Collections.Generic.List[object]]::new()
        GerberVersion = $copy.GerberVersion
    }
    $builder.CommandList.AddRange([object[]]$copy.CommandList)
    return $builder
}
