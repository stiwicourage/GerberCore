function Add-GerberAdoBuildTag {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [int]$BuildId,

        [Parameter(Mandatory)]
        [string]$Tag
    )

    $tagUri = Get-GerberAdoBuildTagUri -Configuration $Configuration -BuildId $BuildId -Tag $Tag
    $httpConfig = Get-GerberHttpConfiguration
    try {
        Invoke-RestMethod `
            -Method Put `
            -Uri $tagUri `
            -ConnectionTimeoutSeconds $httpConfig.ConnectionTimeoutSeconds `
            -OperationTimeoutSeconds $httpConfig.OperationTimeoutSeconds `
            -Headers (Get-GerberAdoJsonRequestHeader -Pat $Pat) `
            -ErrorAction Stop | Out-Null
    } catch {
        throw [System.ArgumentException]::new(
            (Get-GerberAdoMutationFailureMessage `
                -Uri $tagUri `
                -RequestLabel "tag build $BuildId" `
                -CredentialIdentifier $Configuration.CredentialIdentifier `
                -Exception $_.Exception),
            $_.Exception
        )
    }
}
