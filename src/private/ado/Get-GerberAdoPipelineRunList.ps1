function Get-GerberAdoPipelineRunList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$RunListRequest
    )

    $resolutionContext = Get-GerberAdoPipelineRunResolutionContext -RunListRequest $RunListRequest
    $uri = Get-GerberAdoPipelineRunListUri `
        -Configuration $RunListRequest.Configuration `
        -DefinitionId $RunListRequest.DefinitionId `
        -BranchName $RunListRequest.BranchName `
        -Top (Get-GerberAdoPipelineRunListTop -RunListRequest $RunListRequest)
    $response = Invoke-GerberAdoRestRequest `
        -Uri $uri `
        -Pat $RunListRequest.Pat `
        -RequestLabel "pipeline runs for definition $($RunListRequest.DefinitionId)" `
        -CredentialIdentifier $RunListRequest.Configuration.CredentialIdentifier

    return @(
        Get-GerberAdoResponseValueList -Response $response |
            ForEach-Object {
                ConvertTo-GerberAdoPipelineRunItem `
                    -Build $_ `
                    -RunListRequest $RunListRequest `
                    -ResolutionContext $resolutionContext
            }
    )
}

function Get-GerberAdoPipelineRunResolutionContext {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$RunListRequest
    )

    return [pscustomobject]@{
        Configuration = $RunListRequest.Configuration
        Pat           = $RunListRequest.Pat
        BuildCache    = @{}
        TimelineCache = @{}
    }
}

function Get-GerberAdoPipelineRunListTop {
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$RunListRequest
    )

    if ($RunListRequest.PSObject.Properties.Name -contains 'Top') {
        return [int]$RunListRequest.Top
    }

    return 50
}

function Get-GerberAdoPipelineRunListUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [int]$DefinitionId,

        [Parameter(Mandatory)]
        [string]$BranchName,

        [Parameter(Mandatory)]
        [int]$Top
    )

    return Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($Configuration.CollectionUri, "$($Configuration.ProjectName)/_apis/build/builds")) `
        -QueryParameterMap @{
            'api-version' = '7.1'
            definitions   = $DefinitionId
            branchName    = (Get-GerberAdoBuildSourceBranch -BranchName $BranchName)
            queryOrder    = 'queueTimeDescending'
            '$top'        = $Top
        }
}

function ConvertTo-GerberAdoPipelineRunItem {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Build,

        [Parameter(Mandatory)]
        [pscustomobject]$RunListRequest,

        [Parameter(Mandatory)]
        [pscustomobject]$ResolutionContext
    )

    $buildId = [int](Get-GerberAdoPipelineRunPropertyValue -Build $Build -PropertyName 'id')
    $timelineEnvironmentReport = Get-GerberAdoPipelineRunTimelineEnvironmentReport `
        -Build $Build `
        -BuildId $buildId `
        -RunListRequest $RunListRequest `
        -ResolutionContext $ResolutionContext
    $environmentName = Resolve-GerberAdoPipelineRunEnvironmentName `
        -Build $Build `
        -BuildId $buildId `
        -ResolutionContext $ResolutionContext `
        -TimelineEnvironmentReport $timelineEnvironmentReport
    $approvalEnvironmentMap = Get-GerberAdoPipelineRunEffectiveApprovalEnvironmentMap `
        -ApprovalEnvironmentMap $timelineEnvironmentReport.ApprovalEnvironmentMap `
        -EnvironmentName $environmentName
    $pendingApprovalEnvironmentNameList = Get-GerberAdoPipelineRunEffectivePendingApprovalEnvironmentNameList `
        -PendingApprovalEnvironmentNameList @($timelineEnvironmentReport.PendingApprovalEnvironmentNameList) `
        -ApprovalEnvironmentMap $approvalEnvironmentMap
    return [pscustomobject]@{
        BuildId         = $buildId
        BuildNumber     = Get-GerberAdoPipelineRunPropertyValue -Build $Build -PropertyName 'buildNumber'
        DefinitionId    = $RunListRequest.DefinitionId
        DefinitionName  = Get-GerberAdoPipelineRunDefinitionName -Build $Build
        EnvironmentName = $environmentName
        ApprovalEnvironmentMap = $approvalEnvironmentMap
        PendingApprovalEnvironmentNameList = @($pendingApprovalEnvironmentNameList)
        SourceBranch    = Get-GerberAdoPipelineRunPropertyValue -Build $Build -PropertyName 'sourceBranch'
        Status          = Get-GerberAdoPipelineRunPropertyValue -Build $Build -PropertyName 'status'
        Result          = Get-GerberAdoPipelineRunPropertyValue -Build $Build -PropertyName 'result'
        QueueTime       = Get-GerberAdoPipelineRunPropertyValue -Build $Build -PropertyName 'queueTime'
        FinishTime      = Get-GerberAdoPipelineRunPropertyValue -Build $Build -PropertyName 'finishTime'
        RunUrl          = Get-GerberAdoBuildRunUrl -Configuration $RunListRequest.Configuration -BuildId $buildId
    }
}

function Get-GerberAdoPipelineRunTimelineEnvironmentReport {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Build,

        [Parameter(Mandatory)]
        [int]$BuildId,

        [Parameter(Mandatory)]
        [pscustomobject]$RunListRequest,

        [Parameter(Mandatory)]
        [pscustomobject]$ResolutionContext
    )

    $directEnvironmentName = Get-GerberAdoPipelineRunPropertyValue -Build $Build -PropertyName 'environmentName'
    $shouldReadTimeline = [string]::IsNullOrWhiteSpace($directEnvironmentName) -or
        (Test-GerberAdoPipelineRunIncludeApprovalEnvironmentMap -RunListRequest $RunListRequest)
    if (-not $shouldReadTimeline) {
        return [pscustomobject]@{
            RunEnvironmentName   = ''
            ApprovalEnvironmentMap = @{}
            PendingApprovalEnvironmentNameList = @()
        }
    }

    return Get-GerberAdoPipelineRunTimelineEnvironmentReportCore `
        -BuildId $BuildId `
        -ResolutionContext $ResolutionContext
}

function Get-GerberAdoPipelineRunEffectiveApprovalEnvironmentMap {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$ApprovalEnvironmentMap,

        [AllowEmptyString()]
        [string]$EnvironmentName
    )

    if ($ApprovalEnvironmentMap.Count -lt 1) {
        return $ApprovalEnvironmentMap
    }

    $approvalEnvironmentNameList = @(Get-GerberAdoPipelineRunApprovalEnvironmentNameList -ApprovalEnvironmentMap $ApprovalEnvironmentMap)
    if ($approvalEnvironmentNameList.Count -gt 0) {
        return $ApprovalEnvironmentMap
    }

    if ([string]::IsNullOrWhiteSpace($EnvironmentName)) {
        return $ApprovalEnvironmentMap
    }

    $resolvedApprovalEnvironmentMap = @{}
    foreach ($approvalId in @($ApprovalEnvironmentMap.Keys)) {
        $resolvedApprovalEnvironmentMap[[string]$approvalId] = $EnvironmentName
    }

    return $resolvedApprovalEnvironmentMap
}

function Test-GerberAdoPipelineRunIncludeApprovalEnvironmentMap {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$RunListRequest
    )

    if ($RunListRequest.PSObject.Properties.Name -notcontains 'IncludeApprovalEnvironmentMap') {
        return $false
    }

    return [bool]$RunListRequest.IncludeApprovalEnvironmentMap
}

function Get-GerberAdoPipelineRunTimelineEnvironmentReportCore {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$BuildId,

        [Parameter(Mandatory)]
        [pscustomobject]$ResolutionContext
    )

    $timelineRecordList = Get-GerberAdoPipelineRunTimelineRecordListCached `
        -BuildId $BuildId `
        -ResolutionContext $ResolutionContext
    if ($timelineRecordList.Count -eq 0) {
        return [pscustomobject]@{
            RunEnvironmentName   = ''
            ApprovalEnvironmentMap = @{}
            PendingApprovalEnvironmentNameList = @()
        }
    }

    $recordMap = Get-GerberAdoPipelineRunTimelineRecordMap -TimelineRecordList $timelineRecordList
    return [pscustomobject]@{
        RunEnvironmentName   = Get-GerberAdoPipelineRunTimelineReportEnvironmentName `
            -TimelineRecordList $TimelineRecordList `
            -RecordMap $recordMap
        ApprovalEnvironmentMap = Get-GerberAdoPipelineRunApprovalTimelineEnvironmentMap `
            -TimelineRecordList $TimelineRecordList `
            -RecordMap $recordMap
        PendingApprovalEnvironmentNameList = Get-GerberAdoPipelineRunPendingApprovalTimelineEnvironmentNameList `
            -TimelineRecordList $TimelineRecordList `
            -RecordMap $recordMap
    }
}

function Resolve-GerberAdoPipelineRunEnvironmentName {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Build,

        [Parameter(Mandatory)]
        [int]$BuildId,

        [Parameter(Mandatory)]
        [pscustomobject]$ResolutionContext,

        [AllowNull()]
        [pscustomobject]$TimelineEnvironmentReport
    )

    $directEnvironmentName = Resolve-GerberAdoPipelineRunNormalizedEnvironmentName `
        -Candidate (Get-GerberAdoPipelineRunPropertyValue -Build $Build -PropertyName 'environmentName')
    if (-not [string]::IsNullOrWhiteSpace($directEnvironmentName)) {
        return $directEnvironmentName
    }

    $timelineEnvironmentName = Get-GerberAdoPipelineRunTimelineEnvironmentName `
        -BuildId $BuildId `
        -ResolutionContext $ResolutionContext `
        -TimelineEnvironmentReport $TimelineEnvironmentReport
    if (-not [string]::IsNullOrWhiteSpace($timelineEnvironmentName)) {
        return $timelineEnvironmentName
    }

    $templateEnvironmentName = Get-GerberAdoPipelineRunTemplateEnvironmentName -Build $Build
    if (-not [string]::IsNullOrWhiteSpace($templateEnvironmentName)) {
        return $templateEnvironmentName
    }

    $buildResponse = Get-GerberAdoPipelineRunBuildResponse `
        -BuildId $BuildId `
        -ResolutionContext $ResolutionContext
    $detailEnvironmentName = Resolve-GerberAdoPipelineRunNormalizedEnvironmentName `
        -Candidate (Get-GerberAdoPipelineRunPropertyValue -Build $buildResponse -PropertyName 'environmentName')
    if (-not [string]::IsNullOrWhiteSpace($detailEnvironmentName)) {
        return $detailEnvironmentName
    }

    return Get-GerberAdoPipelineRunTemplateEnvironmentName -Build $buildResponse
}

function Get-GerberAdoPipelineRunTimelineEnvironmentName {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$BuildId,

        [Parameter(Mandatory)]
        [pscustomobject]$ResolutionContext,

        [AllowNull()]
        [pscustomobject]$TimelineEnvironmentReport
    )

    if ($null -ne $TimelineEnvironmentReport) {
        return [string]$TimelineEnvironmentReport.RunEnvironmentName
    }

    return (Get-GerberAdoPipelineRunTimelineEnvironmentReportCore `
            -BuildId $BuildId `
            -ResolutionContext $ResolutionContext).RunEnvironmentName
}

function Get-GerberAdoPipelineRunTimelineRecordMap {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$TimelineRecordList
    )

    $recordMap = @{}
    foreach ($record in $TimelineRecordList) {
        if (-not [string]::IsNullOrWhiteSpace($record.Id)) {
            $recordMap[$record.Id] = $record
        }
    }

    return $recordMap
}

function Get-GerberAdoPipelineRunTimelineReportEnvironmentName {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$TimelineRecordList,

        [Parameter(Mandatory)]
        [hashtable]$RecordMap
    )

    $activeStageEnvironmentName = Get-GerberAdoPipelineRunActiveStageEnvironmentName -TimelineRecordList $TimelineRecordList
    if (-not [string]::IsNullOrWhiteSpace($activeStageEnvironmentName)) {
        return $activeStageEnvironmentName
    }

    $approvalEnvironmentMap = Get-GerberAdoPipelineRunApprovalTimelineEnvironmentMap `
        -TimelineRecordList $TimelineRecordList `
        -RecordMap $RecordMap
    $environmentNameList = @(
        $approvalEnvironmentMap.Values |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
    )
    if ($environmentNameList.Count -eq 1) {
        return [string]$environmentNameList[0]
    }

    return Get-GerberAdoPipelineRunSingleStageEnvironmentName `
        -MatchList @(Get-GerberAdoPipelineRunStageEnvironmentMatchList -TimelineRecordList $TimelineRecordList)
}

function Get-GerberAdoPipelineRunActiveStageEnvironmentName {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$TimelineRecordList
    )

    return Get-GerberAdoPipelineRunSingleStageEnvironmentName -MatchList @(
        $TimelineRecordList |
            Where-Object { $_.Type -eq 'Stage' } |
            Where-Object { Test-GerberAdoPipelineRunActiveTimelineRecord -Record $_ } |
            ForEach-Object {
                Resolve-GerberAdoPipelineRunNormalizedEnvironmentName -Candidate $_.Name
            } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
    )
}

function Get-GerberAdoPipelineRunApprovalTimelineEnvironmentMap {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$TimelineRecordList,

        [Parameter(Mandatory)]
        [hashtable]$RecordMap
    )

    $environmentMap = @{}
    foreach ($record in @(Get-GerberAdoPipelineRunApprovalTimelineRecordList -TimelineRecordList $TimelineRecordList)) {
        $environmentName = Get-GerberAdoPipelineRunAncestorEnvironmentName `
            -Record $record `
            -RecordMap $RecordMap
        $environmentMap[[string]$record.Id] = $environmentName
    }

    return $environmentMap
}

function Get-GerberAdoPipelineRunPendingApprovalTimelineEnvironmentNameList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$TimelineRecordList,

        [Parameter(Mandatory)]
        [hashtable]$RecordMap
    )

    return @(
        foreach ($record in @(Get-GerberAdoPipelineRunApprovalTimelineRecordList -TimelineRecordList $TimelineRecordList)) {
            if (-not (Test-GerberAdoPipelineRunPendingApprovalTimelineRecord -Record $record)) {
                continue
            }

            $environmentName = Get-GerberAdoPipelineRunAncestorEnvironmentName `
                -Record $record `
                -RecordMap $RecordMap
            if (-not [string]::IsNullOrWhiteSpace($environmentName)) {
                $environmentName
            }
        }
    ) | Select-Object -Unique
}

function Get-GerberAdoPipelineRunEffectivePendingApprovalEnvironmentNameList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$PendingApprovalEnvironmentNameList,

        [Parameter(Mandatory)]
        [hashtable]$ApprovalEnvironmentMap
    )

    if ($PendingApprovalEnvironmentNameList.Count -gt 0) {
        return [string[]]@($PendingApprovalEnvironmentNameList)
    }

    $approvalEnvironmentNameList = @(Get-GerberAdoPipelineRunApprovalEnvironmentNameList -ApprovalEnvironmentMap $ApprovalEnvironmentMap)
    if ($approvalEnvironmentNameList.Count -ne 1) {
        return [string[]]@()
    }

    return [string[]]@($approvalEnvironmentNameList)
}

function Get-GerberAdoPipelineRunApprovalEnvironmentNameList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$ApprovalEnvironmentMap
    )

    return [string[]]@(
        $ApprovalEnvironmentMap.Values |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
    )
}

function Test-GerberAdoPipelineRunPendingApprovalTimelineRecord {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Record
    )

    $state = [string](Get-GerberAdoPipelineRunObjectPropertyValue -InputObject $Record -PropertyName 'State')
    if (-not [string]::IsNullOrWhiteSpace($state)) {
        return Test-GerberAdoPipelineRunPendingApprovalTimelineValue -Value $state
    }

    $result = [string](Get-GerberAdoPipelineRunObjectPropertyValue -InputObject $Record -PropertyName 'Result')
    if (-not [string]::IsNullOrWhiteSpace($result)) {
        return Test-GerberAdoPipelineRunPendingApprovalTimelineValue -Value $result
    }

    return $true
}

function Test-GerberAdoPipelineRunPendingApprovalTimelineValue {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    return @('pending', 'inprogress', 'notstarted', 'queued') -contains $Value.Trim().ToLowerInvariant()
}

function Test-GerberAdoPipelineRunActiveTimelineRecord {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Record
    )

    $state = [string](Get-GerberAdoPipelineRunObjectPropertyValue -InputObject $Record -PropertyName 'State')
    if (-not [string]::IsNullOrWhiteSpace($state)) {
        return Test-GerberAdoPipelineRunPendingApprovalTimelineValue -Value $state
    }

    $result = [string](Get-GerberAdoPipelineRunObjectPropertyValue -InputObject $Record -PropertyName 'Result')
    if (-not [string]::IsNullOrWhiteSpace($result)) {
        return $false
    }

    return $true
}

function Get-GerberAdoPipelineRunSingleStageEnvironmentName {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$MatchList
    )

    if ($MatchList.Count -ne 1) {
        return ''
    }

    return [string]$MatchList[0]
}

function Get-GerberAdoPipelineRunApprovalTimelineRecordList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$TimelineRecordList
    )

    return @(
        $TimelineRecordList |
            Where-Object { $_.Type -eq 'Checkpoint.Approval' }
    )
}

function Get-GerberAdoPipelineRunStageEnvironmentMatchList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$TimelineRecordList
    )

    return [string[]]@(
        $TimelineRecordList |
            Where-Object { $_.Type -eq 'Stage' } |
            ForEach-Object {
                Resolve-GerberAdoPipelineRunNormalizedEnvironmentName -Candidate $_.Name
            } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
    )
}

function Get-GerberAdoPipelineRunAncestorEnvironmentName {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Record,

        [Parameter(Mandatory)]
        [hashtable]$RecordMap
    )

    $currentRecord = $Record
    while ($null -ne $currentRecord) {
        $environmentName = Resolve-GerberAdoPipelineRunNormalizedEnvironmentName -Candidate $currentRecord.Name
        if (-not [string]::IsNullOrWhiteSpace($environmentName)) {
            return $environmentName
        }

        if ([string]::IsNullOrWhiteSpace($currentRecord.ParentId) -or (-not $RecordMap.ContainsKey($currentRecord.ParentId))) {
            return ''
        }

        $currentRecord = [pscustomobject]$RecordMap[$currentRecord.ParentId]
    }

    return ''
}

function Resolve-GerberAdoPipelineRunNormalizedEnvironmentName {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Candidate
    )

    if ([string]::IsNullOrWhiteSpace($Candidate)) {
        return ''
    }

    $trimmedCandidate = $Candidate.Trim()
    if ($trimmedCandidate -match '(?i)(?<![A-Z0-9])(TC\d+|[A-Z]+\d+)(?![A-Z0-9])') {
        return $matches[1].ToUpperInvariant()
    }

    $comparableCandidate = Get-GerberAdoPipelineRunComparableText -Text $trimmedCandidate
    if ($comparableCandidate.Contains('PREPROD')) {
        return 'PreProd'
    }

    if ($comparableCandidate.Contains('PROD')) {
        return 'Prod'
    }

    return ''
}

function Get-GerberAdoPipelineRunComparableText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }

    return (($Text -replace '[^A-Za-z0-9]', '')).ToUpperInvariant()
}

function Get-GerberAdoPipelineRunTimelineRecordListCached {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$BuildId,

        [Parameter(Mandatory)]
        [pscustomobject]$ResolutionContext
    )

    if (-not $ResolutionContext.TimelineCache.ContainsKey($BuildId)) {
        $ResolutionContext.TimelineCache[$BuildId] = @(
            Get-GerberAdoPipelineRunTimeline `
                -Configuration $ResolutionContext.Configuration `
                -Pat $ResolutionContext.Pat `
                -BuildId $BuildId
        )
    }

    return @($ResolutionContext.TimelineCache[$BuildId])
}

function Get-GerberAdoPipelineRunBuildResponse {
    [OutputType([object])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$BuildId,

        [Parameter(Mandatory)]
        [pscustomobject]$ResolutionContext
    )

    if (-not $ResolutionContext.BuildCache.ContainsKey($BuildId)) {
        $uri = Get-GerberAdoPipelineRunBuildUri -Configuration $ResolutionContext.Configuration -BuildId $BuildId
        $ResolutionContext.BuildCache[$BuildId] = Invoke-GerberAdoRestRequest `
            -Uri $uri `
            -Pat $ResolutionContext.Pat `
            -RequestLabel "pipeline run $BuildId" `
            -CredentialIdentifier $ResolutionContext.Configuration.CredentialIdentifier
    }

    return $ResolutionContext.BuildCache[$BuildId]
}

function Get-GerberAdoPipelineRunBuildUri {
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

function Get-GerberAdoPipelineRunTemplateEnvironmentName {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Build
    )

    $templateEnvironmentName = Resolve-GerberAdoPipelineRunNormalizedEnvironmentName `
        -Candidate (Get-GerberAdoPipelineRunNestedPropertyValue `
            -InputObject $Build `
            -PropertyPath @('templateParameters', 'environmentName'))
    if (-not [string]::IsNullOrWhiteSpace($templateEnvironmentName)) {
        return $templateEnvironmentName
    }

    return Resolve-GerberAdoPipelineRunNormalizedEnvironmentName `
        -Candidate (Get-GerberAdoPipelineRunNestedPropertyValue `
            -InputObject $Build `
            -PropertyPath @('templateParameters', 'environment'))
}

function Get-GerberAdoPipelineRunDefinitionName {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Build
    )

    if ($null -eq $Build) {
        return ''
    }

    if (($Build -is [hashtable]) -and $Build.ContainsKey('definition')) {
        return [string]$Build.definition.name
    }

    if ($Build.PSObject.Properties.Match('definition').Count -eq 0) {
        return ''
    }

    return [string]$Build.definition.name
}

function Get-GerberAdoPipelineRunPropertyValue {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Build,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    $value = Get-GerberAdoPipelineRunObjectPropertyValue -InputObject $Build -PropertyName $PropertyName
    if ($null -eq $value) {
        return ''
    }

    return [string]$value
}

function Get-GerberAdoPipelineRunNestedPropertyValue {
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

        $currentObject = Get-GerberAdoPipelineRunObjectPropertyValue `
            -InputObject $currentObject `
            -PropertyName $propertyName
    }

    if ($null -eq $currentObject) {
        return ''
    }

    return [string]$currentObject
}

function Get-GerberAdoPipelineRunObjectPropertyValue {
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
