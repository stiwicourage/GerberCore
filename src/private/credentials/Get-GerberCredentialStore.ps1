function Get-GerberCredentialStore {
    [OutputType([object])]
    [CmdletBinding()]
    param()

    $storeVariable = Get-Variable -Name 'GerberCredentialStore' -Scope Script -ErrorAction SilentlyContinue
    if ($null -eq $storeVariable -or $null -eq $storeVariable.Value) {
        try {
            $script:GerberCredentialStore = Initialize-GerberCredentialStore
        } catch {
            throw (ConvertTo-GerberCredentialStoreInitializationException -Exception $_.Exception)
        }
    }

    return $script:GerberCredentialStore
}

function ConvertTo-GerberCredentialStoreInitializationException {
    [OutputType([System.InvalidOperationException])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Exception]$Exception
    )

    $null = $Exception
    return [System.InvalidOperationException]::new(
        "Gerber could not initialize secure credential storage. $(Get-GerberCredentialBackendDescription)"
    )
}

function Initialize-GerberCredentialStore {
    [OutputType([object])]
    [CmdletBinding()]
    param()

    Import-GerberCredentialManagerAssembly
    if (-not $IsLinux) {
        return [GitCredentialManager.CredentialManager]::Create('Gerber')
    }

    return Initialize-GerberLinuxCredentialStore
}

function Initialize-GerberLinuxCredentialStore {
    [OutputType([object])]
    [CmdletBinding()]
    param()

    $existingStore = Get-Item -LiteralPath 'Env:GCM_CREDENTIAL_STORE' -ErrorAction SilentlyContinue
    try {
        $env:GCM_CREDENTIAL_STORE = 'secretservice'
        return [GitCredentialManager.CredentialManager]::Create('Gerber')
    } finally {
        Restore-GerberCredentialStoreEnvironment -ExistingStore $existingStore
    }
}

function Restore-GerberCredentialStoreEnvironment {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$ExistingStore
    )

    if ($null -eq $ExistingStore) {
        Remove-Item -LiteralPath 'Env:GCM_CREDENTIAL_STORE' -ErrorAction SilentlyContinue
        return
    }

    $env:GCM_CREDENTIAL_STORE = [string]$ExistingStore.Value
}

function Import-GerberCredentialManagerAssembly {
    [CmdletBinding()]
    param()

    $loadedAssemblyNameList = @(
        [AppDomain]::CurrentDomain.GetAssemblies() |
            ForEach-Object { $_.GetName() }
    )
    Assert-GerberLoadedAssemblyVersion `
        -AssemblyName 'Devlooped.CredentialManager' `
        -ExpectedVersion ([version]'2.7.0.0') `
        -LoadedAssemblyNameList $loadedAssemblyNameList
    Assert-GerberLoadedAssemblyVersion `
        -AssemblyName 'DotNetConfig' `
        -ExpectedVersion ([version]'1.2.0.0') `
        -LoadedAssemblyNameList $loadedAssemblyNameList
    if ($null -ne ('GitCredentialManager.CredentialManager' -as [type])) {
        return
    }

    $libraryPath = Get-GerberCredentialManagerLibraryPath
    Add-Type -Path (Join-Path $libraryPath 'DotNetConfig.dll')
    Add-Type -Path (Join-Path $libraryPath 'Devlooped.CredentialManager.dll')
}

function Assert-GerberLoadedAssemblyVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AssemblyName,

        [Parameter(Mandatory)]
        [version]$ExpectedVersion,

        [Parameter(Mandatory)]
        [Reflection.AssemblyName[]]$LoadedAssemblyNameList
    )

    $loadedAssembly = $LoadedAssemblyNameList |
        Where-Object Name -EQ $AssemblyName |
        Select-Object -First 1
    if ($null -eq $loadedAssembly -or $loadedAssembly.Version -eq $ExpectedVersion) {
        return
    }

    throw [System.InvalidOperationException]::new(
        "Gerber requires $AssemblyName $ExpectedVersion, but version $($loadedAssembly.Version) is already loaded. Start a new PowerShell session before using Gerber credentials."
    )
}

function Get-GerberCredentialManagerLibraryPath {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    $candidatePathList = @(
        (Join-Path $PSScriptRoot 'resources/lib')
        (Join-Path $PSScriptRoot '../../resources/lib')
    )
    foreach ($candidatePath in $candidatePathList) {
        $assemblyPath = Join-Path $candidatePath 'Devlooped.CredentialManager.dll'
        if (Test-Path -LiteralPath $assemblyPath -PathType Leaf) {
            return [System.IO.Path]::GetFullPath($candidatePath)
        }
    }

    throw [System.IO.FileNotFoundException]::new(
        'Gerber could not locate the packaged secure credential storage assemblies.'
    )
}
