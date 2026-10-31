function Resolve-GerberPluginUpdateScopeRootMap {
    param()
    if ($IsWindows) {
        return @{
            CurrentUser = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell/Modules'
            AllUsers    = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'PowerShell/Modules'
        }
    }
    @{
        CurrentUser = Resolve-GerberUnixUserModuleRoot
        AllUsers    = '/usr/local/share/powershell/Modules'
    }
}

function Resolve-GerberUnixUserModuleRoot {
    param()
    $dataRoot = [Environment]::GetEnvironmentVariable('XDG_DATA_HOME')
    if ([string]::IsNullOrWhiteSpace($dataRoot)) {
        $dataRoot = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.local/share'
    }
    if (-not [IO.Path]::IsPathRooted($dataRoot)) {
        throw [System.InvalidOperationException]::new('The user module data directory must be absolute.')
    }
    Join-Path $dataRoot 'powershell/Modules'
}
