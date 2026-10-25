function Get-GerberAdoBuildListByTag {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [string]$Tag
    )

    $buildList = [System.Collections.Generic.List[object]]::new()
    $continuationToken = ''
    do {
        $pageData = Get-GerberAdoBuildListByTagPageData `
            -Configuration $Configuration `
            -Pat $Pat `
            -Tag $Tag `
            -ContinuationToken $continuationToken
        foreach ($build in $pageData.BuildList) {
            $buildList.Add($build)
        }

        $continuationToken = $pageData.ContinuationToken
    } while (-not [string]::IsNullOrWhiteSpace($continuationToken))

    return @($buildList)
}

function Get-GerberAdoBuildListByTagPageData {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [string]$Tag,

        [AllowEmptyString()]
        [string]$ContinuationToken = ''
    )

    $responseEnvelope = Invoke-GerberAdoBuildListByTagRequest `
        -Configuration $Configuration `
        -Pat $Pat `
        -Tag $Tag `
        -ContinuationToken $ContinuationToken
    return [pscustomobject]@{
        BuildList         = @(ConvertTo-GerberAdoTaggedBuildList -Configuration $Configuration -Response (Get-GerberAdoBuildListByTagEnvelopeProperty -ResponseEnvelope $responseEnvelope -PropertyName 'Response'))
        ContinuationToken = Get-GerberAdoBuildListByTagContinuationToken -ResponseHeaders (Get-GerberAdoBuildListByTagEnvelopeProperty -ResponseEnvelope $responseEnvelope -PropertyName 'ResponseHeaders')
    }
}

function Invoke-GerberAdoBuildListByTagRequest {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [string]$Tag,

        [AllowEmptyString()]
        [string]$ContinuationToken = ''
    )

    $uri = Get-GerberAdoBuildListByTagUri `
        -Configuration $Configuration `
        -Tag $Tag `
        -ContinuationToken $ContinuationToken
    $httpConfig = Get-GerberHttpConfiguration
    $requestLabel = "builds with tag '$Tag'"
    $attemptCount = 3
    for ($attemptIndex = 0; $attemptIndex -lt $attemptCount; $attemptIndex++) {
        try {
            $responseHeaders = $null
            $response = Invoke-RestMethod `
                -Method Get `
                -Uri $uri `
                -ConnectionTimeoutSeconds $httpConfig.ConnectionTimeoutSeconds `
                -OperationTimeoutSeconds $httpConfig.OperationTimeoutSeconds `
                -Headers (Get-GerberAdoRequestHeader -Pat $Pat) `
                -ResponseHeadersVariable responseHeaders `
                -ErrorAction Stop
            return [pscustomobject]@{
                Response        = $response
                ResponseHeaders = $responseHeaders
            }
        } catch {
            if (($attemptIndex -lt ($attemptCount - 1)) -and (Test-GerberAdoRetriableFailure -Exception $_.Exception)) {
                Start-Sleep -Seconds (Get-GerberAdoRetryDelay -AttemptNumber ($attemptIndex + 1))
                continue
            }

            throw [System.ArgumentException]::new(
                (Get-GerberAdoRequestFailureMessage `
                    -Uri $uri `
                    -RequestLabel $requestLabel `
                    -CredentialIdentifier $Configuration.CredentialIdentifier `
                    -Exception $_.Exception),
                $_.Exception
            )
        }
    }
}

function Get-GerberAdoBuildListByTagEnvelopeProperty {
    [OutputType([object])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$ResponseEnvelope,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    if (($null -eq $ResponseEnvelope) -or ($ResponseEnvelope.PSObject.Properties.Name -notcontains $PropertyName)) {
        return $null
    }

    return $ResponseEnvelope.$PropertyName
}

function Get-GerberAdoBuildListByTagUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Tag,

        [AllowEmptyString()]
        [string]$ContinuationToken = ''
    )

    $queryParameterMap = [ordered]@{
        'api-version' = '7.1'
        'tagFilters'  = $Tag
        '$top'        = 200
        'queryOrder'  = 'queueTimeDescending'
    }
    if (-not [string]::IsNullOrWhiteSpace($ContinuationToken)) {
        $queryParameterMap.continuationToken = $ContinuationToken
    }

    return Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($Configuration.CollectionUri, "$($Configuration.ProjectName)/_apis/build/builds")) `
        -QueryParameterMap $queryParameterMap
}

function Get-GerberAdoBuildListByTagContinuationToken {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$ResponseHeaders
    )

    if ($null -eq $ResponseHeaders) {
        return ''
    }

    $continuationValue = $null
    if (($ResponseHeaders -is [System.Collections.IDictionary]) -and ($ResponseHeaders.Keys -contains 'x-ms-continuationtoken')) {
        $continuationValue = $ResponseHeaders['x-ms-continuationtoken']
    } elseif ($ResponseHeaders.PSObject.Properties.Name -contains 'x-ms-continuationtoken') {
        $continuationValue = $ResponseHeaders.'x-ms-continuationtoken'
    }

    if ($continuationValue -is [System.Array]) {
        return [string]$continuationValue[0]
    }

    return [string]$continuationValue
}

function ConvertTo-GerberAdoTaggedBuildList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [AllowNull()]
        [object]$Response
    )

    return @(
        Get-GerberAdoResponseValueList -Response $Response |
            ForEach-Object {
                $buildId = [int](Get-GerberAdoTaggedBuildObjectPropertyValue -InputObject $_ -PropertyName 'id')
                $definition = Get-GerberAdoTaggedBuildObjectPropertyValue -InputObject $_ -PropertyName 'definition'
                $definitionId = [int](Get-GerberAdoTaggedBuildObjectPropertyValue -InputObject $definition -PropertyName 'id')
                $queueTime = ConvertTo-GerberAdoBuildQueueTime -QueueTime (Get-GerberAdoTaggedBuildObjectPropertyValue -InputObject $_ -PropertyName 'queueTime')
                [pscustomobject]@{
                    BuildId        = $buildId
                    DefinitionId   = $definitionId
                    DefinitionName = Get-GerberAdoTaggedBuildDisplayValue `
                        -Value (Get-GerberAdoTaggedBuildPropertyValue -InputObject $definition -PropertyName 'name') `
                        -FallbackValue "Pipeline $definitionId"
                    BuildNumber    = Get-GerberAdoTaggedBuildDisplayValue `
                        -Value (Get-GerberAdoTaggedBuildPropertyValue -InputObject $_ -PropertyName 'buildNumber') `
                        -FallbackValue "Build $buildId"
                    Status         = Get-GerberAdoTaggedBuildPropertyValue -InputObject $_ -PropertyName 'status'
                    Result         = Get-GerberAdoTaggedBuildPropertyValue -InputObject $_ -PropertyName 'result'
                    QueueTime      = $queueTime
                    QueueTimeText  = Get-GerberAdoTaggedBuildQueueTimeText -QueueTime $queueTime
                    RunUrl         = Get-GerberAdoTaggedBuildRunUrl -Configuration $Configuration -BuildId $buildId
                }
            }
    )
}

function Get-GerberAdoTaggedBuildPropertyValue {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    $value = Get-GerberAdoTaggedBuildObjectPropertyValue -InputObject $InputObject -PropertyName $PropertyName
    if ($null -eq $value) {
        return ''
    }

    return [string]$value
}

function Get-GerberAdoTaggedBuildObjectPropertyValue {
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

function Get-GerberAdoTaggedBuildDisplayValue {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory)]
        [string]$FallbackValue
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $FallbackValue
    }

    return $Value
}

function ConvertTo-GerberAdoBuildQueueTime {
    [OutputType([datetime])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$QueueTime
    )

    if ($null -eq $QueueTime -or [string]::IsNullOrWhiteSpace([string]$QueueTime)) {
        return [datetime]::MinValue
    }

    return [datetime]$QueueTime
}

function Get-GerberAdoTaggedBuildQueueTimeText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [datetime]$QueueTime
    )

    if ($QueueTime -eq [datetime]::MinValue) {
        return 'Unknown'
    }

    return $QueueTime.ToString('yyyy-MM-dd HH:mm')
}

function Get-GerberAdoTaggedBuildRunUrl {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [int]$BuildId
    )

    return ([System.Uri]::new($Configuration.CollectionUri, "$($Configuration.ProjectName)/_build/results?buildId=$BuildId&view=results")).AbsoluteUri
}
