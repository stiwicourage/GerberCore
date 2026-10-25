function Test-GerberCredential {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Identifier
    )

    $resolvedIdentifier = Resolve-GerberCredentialIdentifier -Identifier $Identifier
    $store = Get-GerberCredentialStore
    $serviceName = Resolve-GerberCredentialServiceName
    $identifierList = @(Invoke-GerberCredentialStoreOperation -Action 'check a credential' -Operation {
            $store.GetAccounts($serviceName)
        }.GetNewClosure())
    return $identifierList -contains $resolvedIdentifier
}
