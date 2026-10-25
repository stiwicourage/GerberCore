function Get-GerberAdoPipelineRunTimeline {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [int]$BuildId
    )

    $uri = Get-GerberAdoPipelineRunTimelineUri -Configuration $Configuration -BuildId $BuildId
    $response = Invoke-GerberAdoRestRequest `
        -Uri $uri `
        -Pat $Pat `
        -RequestLabel "pipeline run timeline $BuildId" `
        -CredentialIdentifier $Configuration.CredentialIdentifier

    return @(
        Get-GerberAdoPipelineRunTimelineRecordList -Response $response |
            ForEach-Object { ConvertTo-GerberAdoPipelineRunTimelineRecord -Record $_ }
    )
}

function Get-GerberAdoPipelineRunTimelineUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [int]$BuildId
    )

    return Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($Configuration.CollectionUri, "$($Configuration.ProjectName)/_apis/build/builds/$BuildId/timeline")) `
        -QueryParameterMap @{ 'api-version' = '7.1' }
}

function Get-GerberAdoPipelineRunTimelineRecordList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Response
    )

    if ($null -eq $Response) {
        return @()
    }

    if (($Response -is [hashtable]) -and $Response.ContainsKey('records')) {
        return @($Response.records)
    }

    if ($Response.PSObject.Properties.Match('records').Count -eq 0) {
        return @()
    }

    return @($Response.records)
}

function ConvertTo-GerberAdoPipelineRunTimelineRecord {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Record
    )

    return [pscustomobject]@{
        Id         = Get-GerberAdoPipelineRunTimelinePropertyValue -Record $Record -PropertyName 'id'
        ParentId   = Get-GerberAdoPipelineRunTimelinePropertyValue -Record $Record -PropertyName 'parentId'
        Type       = Get-GerberAdoPipelineRunTimelinePropertyValue -Record $Record -PropertyName 'type'
        Name       = Get-GerberAdoPipelineRunTimelinePropertyValue -Record $Record -PropertyName 'name'
        Identifier = Get-GerberAdoPipelineRunTimelinePropertyValue -Record $Record -PropertyName 'identifier'
        State      = Get-GerberAdoPipelineRunTimelinePropertyValue -Record $Record -PropertyName 'state'
        Result     = Get-GerberAdoPipelineRunTimelinePropertyValue -Record $Record -PropertyName 'result'
    }
}

function Get-GerberAdoPipelineRunTimelinePropertyValue {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Record,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    if ($null -eq $Record) {
        return ''
    }

    if (($Record -is [hashtable]) -and $Record.ContainsKey($PropertyName)) {
        return [string]$Record[$PropertyName]
    }

    if ($Record.PSObject.Properties.Match($PropertyName).Count -eq 0) {
        return ''
    }

    return [string]$Record.$PropertyName
}
