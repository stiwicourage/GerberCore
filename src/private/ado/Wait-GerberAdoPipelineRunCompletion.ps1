function Wait-GerberAdoPipelineRunCompletion {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$RunWaitRequest
    )

    $deadline = (Get-Date).AddSeconds((Get-GerberAdoPipelineRunWaitOptionValue `
            -RunWaitRequest $RunWaitRequest `
            -PropertyName 'TimeoutSeconds' `
            -DefaultValue 1800))
    while ((Get-Date) -lt $deadline) {
        $run = Get-GerberAdoPipelineRun `
            -Configuration $RunWaitRequest.Configuration `
            -Pat $RunWaitRequest.Pat `
            -BuildId $RunWaitRequest.BuildId `
            -IncludeApprovalEnvironmentMap ($RunWaitRequest.PSObject.Properties.Name -contains 'SelectedEnvironmentName')
        if ($run.Status -eq 'completed') {
            if ($run.Result -eq 'succeeded') {
                return $run
            }

            throw [System.ArgumentException]::new(
                "Gerber saw Azure DevOps run '$($run.BuildNumber)' ($($RunWaitRequest.BuildId)) finish with result '$($run.Result)'."
            )
        }

        if (Test-GerberAdoPipelineRunSelectedEnvironmentReached `
                -RunWaitRequest $RunWaitRequest `
                -Run $run) {
            return $run
        }

        Start-Sleep -Seconds (Get-GerberAdoPipelineRunWaitOptionValue `
                -RunWaitRequest $RunWaitRequest `
                -PropertyName 'PollIntervalSeconds' `
                -DefaultValue 5)
    }

    throw [System.ArgumentException]::new(
        "Gerber timed out while waiting for Azure DevOps run '$($RunWaitRequest.BuildId)' to finish."
    )
}

function Get-GerberAdoPipelineRunWaitOptionValue {
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$RunWaitRequest,

        [Parameter(Mandatory)]
        [string]$PropertyName,

        [Parameter(Mandatory)]
        [int]$DefaultValue
    )

    if ($RunWaitRequest.PSObject.Properties.Name -contains $PropertyName) {
        return [int]$RunWaitRequest.$PropertyName
    }

    return $DefaultValue
}

function Get-GerberAdoPipelineRun {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [int]$BuildId,

        [bool]$IncludeApprovalEnvironmentMap = $false
    )

    $uri = Get-GerberAdoPipelineRunUri -Configuration $Configuration -BuildId $BuildId
    $response = Invoke-GerberAdoRestRequest `
        -Uri $uri `
        -Pat $Pat `
        -RequestLabel "pipeline run $BuildId" `
        -CredentialIdentifier $Configuration.CredentialIdentifier

    $runListRequest = [pscustomobject]@{
        Configuration                = $Configuration
        Pat                          = $Pat
        DefinitionId                 = [int](Get-GerberAdoPipelineRunDefinitionId -Build $response)
        IncludeApprovalEnvironmentMap = $IncludeApprovalEnvironmentMap
    }
    return ConvertTo-GerberAdoPipelineRunItem `
        -Build $response `
        -RunListRequest $runListRequest `
        -ResolutionContext (Get-GerberAdoPipelineRunResolutionContext -RunListRequest $runListRequest)
}

function Test-GerberAdoPipelineRunSelectedEnvironmentReached {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$RunWaitRequest,

        [Parameter(Mandatory)]
        [pscustomobject]$Run
    )

    $selectedEnvironmentName = Get-GerberAdoPipelineRunSelectedEnvironmentName -RunWaitRequest $RunWaitRequest
    if ([string]::IsNullOrWhiteSpace($selectedEnvironmentName)) {
        return $false
    }

    $waitingEnvironmentNameList = @(Get-GerberAdoPipelineRunWaitingEnvironmentNameList -Run $Run)
    if (($waitingEnvironmentNameList.Count -gt 0) -and (-not (Test-GerberAdoPipelineRunEnvironmentNameMatch `
                    -CandidateList $waitingEnvironmentNameList `
                    -SelectedEnvironmentName $selectedEnvironmentName))) {
        return $true
    }

    if ([string]::IsNullOrWhiteSpace([string]$Run.EnvironmentName)) {
        return $false
    }

    return (-not (Test-GerberAdoPipelineRunEnvironmentNameMatch `
                -CandidateList @([string]$Run.EnvironmentName) `
                -SelectedEnvironmentName $selectedEnvironmentName))
}

function Get-GerberAdoPipelineRunSelectedEnvironmentName {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$RunWaitRequest
    )

    if ($RunWaitRequest.PSObject.Properties.Name -notcontains 'SelectedEnvironmentName') {
        return ''
    }

    return [string]$RunWaitRequest.SelectedEnvironmentName
}

function Get-GerberAdoPipelineRunWaitingEnvironmentNameList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Run
    )

    if ($Run.PSObject.Properties.Name -contains 'PendingApprovalEnvironmentNameList') {
        return [string[]]@(
            @($Run.PendingApprovalEnvironmentNameList) |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Select-Object -Unique
        )
    }

    if ($Run.PSObject.Properties.Name -notcontains 'ApprovalEnvironmentMap') {
        return [string[]]@()
    }

    if ($Run.ApprovalEnvironmentMap -isnot [hashtable]) {
        return [string[]]@()
    }

    return [string[]]@(
        $Run.ApprovalEnvironmentMap.Values |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
    )
}

function Test-GerberAdoPipelineRunEnvironmentNameMatch {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$CandidateList,

        [Parameter(Mandatory)]
        [string]$SelectedEnvironmentName
    )

    foreach ($candidate in $CandidateList) {
        if ($candidate.Trim() -ieq $SelectedEnvironmentName.Trim()) {
            return $true
        }
    }

    return $false
}

function Get-GerberAdoPipelineRunUri {
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

function Get-GerberAdoPipelineRunDefinitionId {
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Build
    )

    if ($null -eq $Build) {
        return 0
    }

    if (($Build -is [hashtable]) -and $Build.ContainsKey('definition')) {
        return [int]$Build.definition.id
    }

    if ($Build.PSObject.Properties.Match('definition').Count -eq 0) {
        return 0
    }

    return [int]$Build.definition.id
}
