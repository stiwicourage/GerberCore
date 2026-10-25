function Add-GerberAdoBuildRetentionLeaseIfMissing {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [int]$DefinitionId,

        [Parameter(Mandatory)]
        [int]$BuildId
    )

    $leaseRequest = [pscustomobject]@{
        Configuration = $Configuration
        Pat           = $Pat
        DefinitionId  = $DefinitionId
        BuildId       = $BuildId
        OwnerId       = Get-GerberAdoBuildRetentionLeaseOwnerId
        DaysValid     = Get-GerberAdoBuildRetentionLeaseDaysValid
    }
    $existingLeaseList = @(Get-GerberAdoBuildRetentionLeaseListForOwner -LeaseRequest $leaseRequest)
    if ($existingLeaseList.Count -gt 0) {
        return [pscustomobject]@{
            Created   = $false
            LeaseList = $existingLeaseList
        }
    }

    return [pscustomobject]@{
        Created   = $true
        LeaseList = @(Add-GerberAdoBuildRetentionLease -LeaseRequest $leaseRequest)
    }
}

function Get-GerberAdoBuildRetentionLeaseListForOwner {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$LeaseRequest
    )

    $leaseUri = Get-GerberAdoBuildRetentionLeaseListUri -LeaseRequest $LeaseRequest
    $httpConfig = Get-GerberHttpConfiguration
    try {
        $response = Invoke-RestMethod `
            -Method Get `
            -Uri $leaseUri `
            -ConnectionTimeoutSeconds $httpConfig.ConnectionTimeoutSeconds `
            -OperationTimeoutSeconds $httpConfig.OperationTimeoutSeconds `
            -Headers (Get-GerberAdoRequestHeader -Pat $LeaseRequest.Pat) `
            -ErrorAction Stop
        return @(Get-GerberAdoBuildRetentionLeaseResponseValueList -Response $response)
    } catch {
        throw [System.ArgumentException]::new(
            (Get-GerberAdoRequestFailureMessage `
                -Uri $leaseUri `
                -RequestLabel "retention leases for build $($LeaseRequest.BuildId)" `
                -CredentialIdentifier $LeaseRequest.Configuration.CredentialIdentifier `
                -Exception $_.Exception),
            $_.Exception
        )
    }
}

function Get-GerberAdoBuildRetentionLeaseResponseValueList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Response
    )

    if ($null -eq $Response) {
        return @()
    }

    if (($Response -is [System.Collections.IEnumerable]) -and ($Response -isnot [string]) -and ($Response -isnot [pscustomobject])) {
        return @($Response)
    }

    if ($Response.PSObject.Properties.Name -contains 'value') {
        return @($Response.value)
    }

    return @($Response)
}

function Add-GerberAdoBuildRetentionLease {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$LeaseRequest
    )

    $leaseUri = Get-GerberAdoBuildRetentionLeaseMutationUri -LeaseRequest $LeaseRequest
    $httpConfig = Get-GerberHttpConfiguration
    $body = @(@{
            daysValid       = $LeaseRequest.DaysValid
            definitionId    = $LeaseRequest.DefinitionId
            ownerId         = $LeaseRequest.OwnerId
            protectPipeline = $false
            runId           = $LeaseRequest.BuildId
        }) | ConvertTo-Json -Depth 5

    try {
        return @(Invoke-RestMethod `
            -Method Post `
            -Uri $leaseUri `
            -ConnectionTimeoutSeconds $httpConfig.ConnectionTimeoutSeconds `
            -OperationTimeoutSeconds $httpConfig.OperationTimeoutSeconds `
            -Headers (Get-GerberAdoJsonRequestHeader -Pat $LeaseRequest.Pat) `
            -Body $body `
            -ErrorAction Stop)
    } catch {
        throw [System.ArgumentException]::new(
            (Get-GerberAdoMutationFailureMessage `
                -Uri $leaseUri `
                -RequestLabel "create retention lease for build $($LeaseRequest.BuildId)" `
                -CredentialIdentifier $LeaseRequest.Configuration.CredentialIdentifier `
                -Exception $_.Exception),
            $_.Exception
        )
    }
}

function Get-GerberAdoBuildRetentionLeaseListUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$LeaseRequest
    )

    return Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($LeaseRequest.Configuration.CollectionUri, "$($LeaseRequest.Configuration.ProjectName)/_apis/build/retention/leases")) `
        -QueryParameterMap @{
            ownerId      = $LeaseRequest.OwnerId
            definitionId = $LeaseRequest.DefinitionId
            runId        = $LeaseRequest.BuildId
            'api-version' = '7.1'
        }
}

function Get-GerberAdoBuildRetentionLeaseMutationUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$LeaseRequest
    )

    return Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($LeaseRequest.Configuration.CollectionUri, "$($LeaseRequest.Configuration.ProjectName)/_apis/build/retention/leases")) `
        -QueryParameterMap @{ 'api-version' = '7.1' }
}

function Get-GerberAdoBuildRetentionLeaseOwnerId {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    return 'Gerber.ProdRetention'
}

function Get-GerberAdoBuildRetentionLeaseDaysValid {
    [OutputType([int])]
    [CmdletBinding()]
    param()

    return 36500
}
