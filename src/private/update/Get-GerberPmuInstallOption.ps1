function Get-GerberPmuInstallOption {
    $command = Get-Command -Name Install-PSModuleUpdate -ErrorAction SilentlyContinue
    if ($command -and $command.Parameters.ContainsKey('ReplaceUnmanagedInstallation')) {
        return @{ ReplaceUnmanagedInstallation = $true }
    }
    @{}
}
