function Get-GerberAdoWorkItemFieldMap {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$WorkItemRequest
    )

    $response = Invoke-GerberAdoRestRequest `
        -Uri (Get-GerberAdoWorkItemUri -WorkItemRequest $WorkItemRequest) `
        -Pat $WorkItemRequest.Pat `
        -RequestLabel "work item $($WorkItemRequest.WorkItemId)" `
        -CredentialIdentifier $WorkItemRequest.Configuration.CredentialIdentifier

    return ConvertTo-GerberAdoWorkItemFieldMap `
        -Response $response `
        -WorkItemId $WorkItemRequest.WorkItemId
}

function Get-GerberAdoWorkItemUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$WorkItemRequest
    )

    return Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new(
                $WorkItemRequest.Configuration.CollectionUri,
                "$($WorkItemRequest.Configuration.ProjectName)/_apis/wit/workitems/$($WorkItemRequest.WorkItemId)"
            )) `
        -QueryParameterMap @{ 'api-version' = '7.1' }
}

function ConvertTo-GerberAdoWorkItemFieldMap {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Response,

        [Parameter(Mandatory)]
        [int]$WorkItemId
    )

    $fieldProperty = $Response.PSObject.Properties['fields']
    if (($null -eq $fieldProperty) -or ($null -eq $fieldProperty.Value)) {
        throw [System.ArgumentException]::new(
            "Gerber could not read fields from Azure DevOps work item $WorkItemId."
        )
    }

    return ConvertTo-GerberAdoFieldMap -FieldObject $fieldProperty.Value
}

function ConvertTo-GerberAdoFieldMap {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$FieldObject
    )

    $fieldMap = @{}
    foreach ($property in $FieldObject.PSObject.Properties) {
        $fieldMap[$property.Name] = $property.Value
    }

    return $fieldMap
}
