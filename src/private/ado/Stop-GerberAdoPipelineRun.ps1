function Stop-GerberAdoPipelineRun {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [int]$BuildId
    )

    $null = $PSCmdlet.ShouldProcess("pipeline run $BuildId", 'cancel Azure DevOps pipeline run')
    $runUri = Get-GerberAdoPipelineRunStopUri -Configuration $Configuration -BuildId $BuildId
    $httpConfig = Get-GerberHttpConfiguration
    $body = @{ status = 'cancelling' } | ConvertTo-Json
    try {
        Invoke-RestMethod `
            -Method Patch `
            -Uri $runUri `
            -ConnectionTimeoutSeconds $httpConfig.ConnectionTimeoutSeconds `
            -OperationTimeoutSeconds $httpConfig.OperationTimeoutSeconds `
            -Headers (Get-GerberAdoJsonRequestHeader -Pat $Pat) `
            -Body $body `
            -ErrorAction Stop | Out-Null
    } catch {
        throw [System.ArgumentException]::new(
            (Get-GerberAdoMutationFailureMessage `
                -Uri $runUri `
                -RequestLabel "cancel pipeline run $BuildId" `
                -CredentialIdentifier $Configuration.CredentialIdentifier `
                -Exception $_.Exception),
            $_.Exception
        )
    }
}

function Get-GerberAdoPipelineRunStopUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [int]$BuildId
    )

    return Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($Configuration.CollectionUri, "$($Configuration.ProjectName)/_apis/build/builds/$BuildId")) `
        -QueryParameterMap @{ 'api-version' = '7.1' }
}
