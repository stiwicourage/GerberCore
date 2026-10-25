function Use-GerberCredentialStore {
    [OutputType([bool])]
    [CmdletBinding()]
    param()

    Get-GerberCredentialInfo | Out-Null
    return $true
}
