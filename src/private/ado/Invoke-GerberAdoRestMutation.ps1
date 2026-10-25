function Invoke-GerberAdoRestMutation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$MutationContext
    )

    $httpConfig = Get-GerberHttpConfiguration
    $headers = Get-GerberAdoRequestHeader -Pat $MutationContext.Pat
    try {
        $null = Invoke-RestMethod `
            -Method $MutationContext.Method `
            -Uri $MutationContext.Uri `
            -Headers $headers `
            -Body $MutationContext.Body `
            -ContentType 'application/json' `
            -ConnectionTimeoutSeconds $httpConfig.ConnectionTimeoutSeconds `
            -OperationTimeoutSeconds $httpConfig.OperationTimeoutSeconds `
            -ErrorAction Stop
    } catch {
        throw (Get-GerberAdoMutationFailure -MutationContext $MutationContext -Exception $_.Exception)
    }
}

function Get-GerberAdoMutationFailure {
    [OutputType([System.ArgumentException])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$MutationContext,

        [AllowNull()]
        [System.Exception]$Exception
    )

    $message = Get-GerberAdoRequestFailureMessage `
        -Uri $MutationContext.Uri `
        -RequestLabel $MutationContext.RequestLabel `
        -CredentialIdentifier $MutationContext.CredentialIdentifier `
        -Exception $Exception
    return [System.ArgumentException]::new($message, $Exception)
}
