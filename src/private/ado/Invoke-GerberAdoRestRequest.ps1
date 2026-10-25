function Invoke-GerberAdoRestRequest {
    [OutputType([object])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$Uri,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [string]$RequestLabel,

        [Parameter(Mandatory)]
        [Alias('CredentialIdentifier')]
        [string]$PatAccountIdentifier
    )

    $httpConfig = Get-GerberHttpConfiguration
    $attemptCount = 3
    for ($attemptIndex = 0; $attemptIndex -lt $attemptCount; $attemptIndex++) {
        try {
            return Invoke-RestMethod `
                -Method Get `
                -Uri $Uri `
                -ConnectionTimeoutSeconds $httpConfig.ConnectionTimeoutSeconds `
                -OperationTimeoutSeconds $httpConfig.OperationTimeoutSeconds `
                -Headers (Get-GerberAdoRequestHeader -Pat $Pat) `
                -ErrorAction Stop
        } catch {
            if (($attemptIndex -lt ($attemptCount - 1)) -and (Test-GerberAdoRetriableFailure -Exception $_.Exception)) {
                Start-Sleep -Seconds (Get-GerberAdoRetryDelay -AttemptNumber ($attemptIndex + 1))
                continue
            }

            throw [System.ArgumentException]::new(
                (Get-GerberAdoRequestFailureMessage `
                    -Uri $Uri `
                    -RequestLabel $RequestLabel `
                    -PatAccountIdentifier $PatAccountIdentifier `
                    -Exception $_.Exception),
                $_.Exception
            )
        }
    }
}
