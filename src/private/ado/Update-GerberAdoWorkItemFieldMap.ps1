function Update-GerberAdoWorkItemFieldMap {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$UpdateRequest
    )

    $fieldValueMap = Get-GerberAdoWorkItemFieldValueMap -UpdateRequest $UpdateRequest
    $fieldNameList = @($fieldValueMap.Keys | Sort-Object)
    $target = "work item $($UpdateRequest.WorkItemId)"
    $action = "update fields $($fieldNameList -join ', ')"

    $null = $PSCmdlet.ShouldProcess($target, $action)
    $uri = Get-GerberAdoWorkItemUpdateUri -Configuration $UpdateRequest.Configuration -WorkItemId $UpdateRequest.WorkItemId
    $httpConfig = Get-GerberHttpConfiguration
    $body = ConvertTo-Json -InputObject (Get-GerberAdoWorkItemPatchOperationList -FieldValueMap $fieldValueMap) -Depth 10 -Compress
    $headers = Get-GerberAdoRequestHeader -Pat $UpdateRequest.Pat
    $headers.Accept = 'application/json'
    $headers.'Content-Type' = 'application/json-patch+json'

    try {
        Invoke-RestMethod `
            -Method Patch `
            -Uri $uri `
            -ConnectionTimeoutSeconds $httpConfig.ConnectionTimeoutSeconds `
            -OperationTimeoutSeconds $httpConfig.OperationTimeoutSeconds `
            -Headers $headers `
            -Body $body `
            -ErrorAction Stop | Out-Null
    } catch {
        throw [System.ArgumentException]::new(
            (Get-GerberAdoMutationFailureMessage `
                -Uri $uri `
                -RequestLabel "update $target" `
                -CredentialIdentifier $UpdateRequest.Configuration.CredentialIdentifier `
                -Exception $_.Exception),
            $_.Exception
        )
    }
}

function Get-GerberAdoWorkItemFieldValueMap {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$UpdateRequest
    )

    $fieldValueMap = @{}
    if ($UpdateRequest.PSObject.Properties.Name -contains 'FieldValueMap') {
        $fieldValueMap = @($UpdateRequest.FieldValueMap)[0]
    }

    if (($fieldValueMap -isnot [System.Collections.IDictionary]) -or ($fieldValueMap.Count -lt 1)) {
        throw [System.ArgumentException]::new(
            'Gerber plugin ADO work item updates require at least one field value.'
        )
    }

    return $fieldValueMap
}

function Get-GerberAdoWorkItemUpdateUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [int]$WorkItemId
    )

    return Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($Configuration.CollectionUri, "$($Configuration.ProjectName)/_apis/wit/workitems/$WorkItemId")) `
        -QueryParameterMap @{ 'api-version' = '7.1' }
}

function Get-GerberAdoWorkItemPatchOperationList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$FieldValueMap
    )

    return @(
        foreach ($fieldReferenceName in @($FieldValueMap.Keys | Sort-Object)) {
            @{
                op    = 'replace'
                path  = "/fields/$fieldReferenceName"
                value = $FieldValueMap[$fieldReferenceName]
            }
        }
    )
}
