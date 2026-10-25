function Get-GerberCredentialInfo {
    [OutputType([object[]])]
    [CmdletBinding()]
    param()

    $store = Get-GerberCredentialStore
    $serviceName = Resolve-GerberCredentialServiceName
    $identifierList = @(Invoke-GerberCredentialStoreOperation -Action 'list credentials' -Operation {
            $store.GetAccounts($serviceName)
        }.GetNewClosure())
    return @(
        foreach ($identifier in ($identifierList | Sort-Object)) {
            [pscustomobject][ordered]@{
                Identifier = Resolve-GerberCredentialIdentifier -Identifier $identifier
            }
        }
    )
}
