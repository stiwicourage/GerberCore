function Enable-GerberPlugin {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Guid
    )

    $pluginModule = Get-GerberInstalledPluginModuleByGuid -Guid $Guid
    if (-not (Test-GerberPluginActiveGuid -Guid $Guid)) {
        Complete-GerberPluginEnable -PluginModule $pluginModule
    }
    return $pluginModule
}

function Test-GerberPluginActiveGuid {
    param(
        [string]$Guid
    )

    $activePlugin = Get-GerberRegisteredPluginStateList |
        Where-Object { $_.Guid -ieq $Guid } | Select-Object -First 1
    return $null -ne $activePlugin
}

function Complete-GerberPluginEnable {
    param(
        [pscustomobject]$PluginModule
    )

    Register-GerberPlugin -PluginModule $PluginModule
    try {
        $null = Resolve-GerberPluginApproval -PluginModule $PluginModule -ExplicitApproval
    } catch {
        Unregister-GerberPlugin -Guid $PluginModule.Guid
        throw [System.InvalidOperationException]::new(
            "Gerber could not save the enabled state for plugin '$($PluginModule.Name)': $($_.Exception.Message)",
            $_.Exception
        )
    }
}

function Get-GerberInstalledPluginModuleByGuid {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Guid
    )

    $pluginModule = Get-GerberPluginManifestMetadataList -PluginModulePathList (Get-GerberDefaultPluginModulePathList) |
        Where-Object { [string]$_.Guid -ieq $Guid } |
        Sort-Object @{ Expression = { [version]$_.Version }; Descending = $true } |
        Select-Object -First 1
    if ($null -eq $pluginModule) {
        throw [System.InvalidOperationException]::new(
            "Gerber plugin '$Guid' is no longer installed and cannot be enabled."
        )
    }

    Assert-GerberPluginModuleManifest -ModuleInfo $pluginModule
    return $pluginModule
}
