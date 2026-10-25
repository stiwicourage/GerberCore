function Assert-GerberPluginRegistrationIdentity {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()][object[]]$PluginList,
        [pscustomobject]$PluginModule
    )

    $collision = $PluginList | Where-Object { $_.Name -ieq $PluginModule.Name -and $_.Guid -ine $PluginModule.Guid } | Select-Object -First 1
    if ($null -ne $collision) {
        throw [System.InvalidOperationException]::new(
            "Gerber cannot register plugin '$($PluginModule.Guid)' because module name '$($PluginModule.Name)' is already active for GUID '$($collision.Guid)'."
        )
    }
}
