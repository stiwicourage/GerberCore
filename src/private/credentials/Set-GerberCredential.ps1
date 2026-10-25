function Set-GerberCredential {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Identifier,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Secret
    )

    $resolvedIdentifier = Resolve-GerberCredentialIdentifier -Identifier $Identifier
    if (-not $PSCmdlet.ShouldProcess($resolvedIdentifier, 'Store credential')) {
        return
    }

    $store = Get-GerberCredentialStore
    $serviceName = Resolve-GerberCredentialServiceName
    $secretValue = $Secret
    Invoke-GerberCredentialStoreOperation -Action 'store a credential' -Operation {
        $store.AddOrUpdate($serviceName, $resolvedIdentifier, $secretValue)
    }.GetNewClosure() | Out-Null
    return [pscustomobject][ordered]@{
        Identifier = $resolvedIdentifier
    }
}
