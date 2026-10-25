function Invoke-GerberCredentialStoreOperation {
    [OutputType([object])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [scriptblock]$Operation
    )

    try {
        return & $Operation
    } catch {
        $backend = Get-GerberCredentialBackendDescription
        throw [System.InvalidOperationException]::new(
            "Gerber could not $Action because secure credential storage is unavailable. $backend"
        )
    }
}

function Get-GerberCredentialBackendDescription {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    if ($IsMacOS) {
        return 'Verify that secure credential storage is available for your user account, then try again.'
    }

    if ($IsWindows) {
        return 'Verify that secure credential storage is available for your user account, then try again.'
    }

    return 'Linux requires an available desktop secret-storage session. Ensure D-Bus and libsecret support are available, then try again. Gerber never falls back to plaintext storage.'
}
