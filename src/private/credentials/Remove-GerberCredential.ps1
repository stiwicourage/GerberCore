function Remove-GerberCredential {
    [OutputType([bool])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Identifier
    )

    $resolvedIdentifier = Resolve-GerberCredentialIdentifier -Identifier $Identifier
    if (-not $PSCmdlet.ShouldProcess($resolvedIdentifier, 'Remove credential')) {
        return $false
    }

    $store = Get-GerberCredentialStore
    $serviceName = Resolve-GerberCredentialServiceName
    return [bool](Invoke-GerberCredentialStoreOperation -Action 'remove a credential' -Operation {
            $store.Remove($serviceName, $resolvedIdentifier)
        }.GetNewClosure())
}
