function Get-GerberCredential {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Identifier
    )

    $resolvedIdentifier = Resolve-GerberCredentialIdentifier -Identifier $Identifier
    $store = Get-GerberCredentialStore
    $serviceName = Resolve-GerberCredentialServiceName
    $credential = Invoke-GerberCredentialStoreOperation -Action 'read a credential' -Operation {
        $store.Get($serviceName, $resolvedIdentifier)
    }.GetNewClosure()
    if ($null -eq $credential) {
        return $null
    }

    return [string]$credential.Password
}
