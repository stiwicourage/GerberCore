function Get-GerberAdoPendingApprovalList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [int]$EnvironmentId
    )

    $uri = Get-GerberAdoPendingApprovalListUri -Configuration $Configuration -EnvironmentId $EnvironmentId
    $response = Invoke-GerberAdoRestRequest `
        -Uri $uri `
        -Pat $Pat `
        -RequestLabel (Get-GerberAdoPendingApprovalRequestLabel -EnvironmentId $EnvironmentId) `
        -CredentialIdentifier $Configuration.CredentialIdentifier

    return @(
        Get-GerberAdoResponseValueList -Response $response |
            ForEach-Object { ConvertTo-GerberAdoPendingApprovalItem -Approval $_ }
    )
}

function Get-GerberAdoPendingApprovalRequestLabel {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [int]$EnvironmentId
    )

    if ($EnvironmentId -gt 0) {
        return "pending approvals for environment $EnvironmentId"
    }

    return 'pending approvals'
}

function Get-GerberAdoPendingApprovalListUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [int]$EnvironmentId
    )

    return Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($Configuration.CollectionUri, "$($Configuration.ProjectName)/_apis/pipelines/approvals")) `
        -QueryParameterMap (Get-GerberAdoPendingApprovalQueryParameterMap -EnvironmentId $EnvironmentId)
}

function Get-GerberAdoPendingApprovalQueryParameterMap {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [int]$EnvironmentId
    )

    $queryParameterMap = @{
        'api-version' = '7.2-preview.2'
        state         = 'pending'
        '$expand'     = 'steps'
    }
    if ($EnvironmentId -gt 0) {
        $queryParameterMap.environmentId = $EnvironmentId
    }

    return $queryParameterMap
}

function ConvertTo-GerberAdoPendingApprovalItem {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Approval
    )

    return [pscustomobject]@{
        ApprovalId     = Get-GerberAdoPendingApprovalPropertyValue -Approval $Approval -PropertyName 'id'
        Status         = Get-GerberAdoPendingApprovalPropertyValue -Approval $Approval -PropertyName 'status'
        DefinitionId   = [int](Get-GerberAdoPendingApprovalNestedValue -InputObject $Approval -PropertyPath @('pipeline', 'id'))
        DefinitionName = Get-GerberAdoPendingApprovalNestedValue -InputObject $Approval -PropertyPath @('pipeline', 'name')
        RunId          = [int](Get-GerberAdoPendingApprovalNestedValue -InputObject $Approval -PropertyPath @('pipeline', 'owner', 'id'))
        RunName        = Get-GerberAdoPendingApprovalNestedValue -InputObject $Approval -PropertyPath @('pipeline', 'owner', 'name')
    }
}

function Get-GerberAdoPendingApprovalPropertyValue {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Approval,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    $value = Get-GerberAdoPendingApprovalObjectPropertyValue -InputObject $Approval -PropertyName $PropertyName
    if ($null -eq $value) {
        return ''
    }

    return [string]$value
}

function Get-GerberAdoPendingApprovalNestedValue {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string[]]$PropertyPath
    )

    $currentObject = $InputObject
    foreach ($propertyName in $PropertyPath) {
        if ($null -eq $currentObject) {
            return ''
        }

        $currentObject = Get-GerberAdoPendingApprovalObjectPropertyValue -InputObject $currentObject -PropertyName $propertyName
    }

    if ($null -eq $currentObject) {
        return ''
    }

    return [string]$currentObject
}

function Get-GerberAdoPendingApprovalObjectPropertyValue {
    [OutputType([object])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if (($InputObject -is [hashtable]) -and $InputObject.ContainsKey($PropertyName)) {
        return $InputObject[$PropertyName]
    }

    if ($InputObject.PSObject.Properties.Match($PropertyName).Count -eq 0) {
        return $null
    }

    return $InputObject.$PropertyName
}
