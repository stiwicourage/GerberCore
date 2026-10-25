function Invoke-GerberPipelineTagMutation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Operation
    )

    $context = Get-GerberPipelineReleaseContext -CommandLabel $Operation.CommandLabel
    while ($true) {
        Write-GerberPipelineTagMutationTrace -Operation $Operation -EventName 'loop' -Data @{}
        $currentTag = Read-GerberPipelineTagMutationCurrentTagOrNull -Operation $Operation
        if ($null -eq $currentTag) {
            return
        }

        Write-GerberPipelineTagMutationTrace -Operation $Operation -EventName 'current-tag' -Data @{ CurrentTag = $currentTag }
        $flowResult = Invoke-GerberPipelineTagMutationCurrentTagFlow `
            -Context $context `
            -Operation $Operation `
            -CurrentTag $currentTag
        if ($flowResult.ReturnToParent) {
            return
        }
    }
}

function Write-GerberPipelineTagMutationTrace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Operation,

        [Parameter(Mandatory)]
        [string]$EventName,

        [Parameter(Mandatory)]
        [hashtable]$Data
    )

    $resolvedEventName = if ($EventName -eq 'loop') {
        "nav-$($Operation.TracePrefix)-loop"
    } else {
        "$($Operation.TracePrefix)-$EventName"
    }

    Write-GerberPromptTrace -EventName $resolvedEventName -Data $Data
}

function Invoke-GerberPipelineTagMutationCurrentTagFlow {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [pscustomobject]$Operation,

        [Parameter(Mandatory)]
        [string]$CurrentTag
    )

    while ($true) {
        $planInput = Get-GerberPipelineTagMutationPlanInputOrNull -Operation $Operation -CurrentTag $CurrentTag
        if ($null -eq $planInput) {
            return [pscustomobject]@{ ReturnToParent = $false }
        }

        $plan = Get-GerberPipelineTagMutationPlanOrNull `
            -Context $Context `
            -Operation $Operation `
            -CurrentTag $CurrentTag `
            -NewTag $planInput.NewTag
        if ($null -eq $plan) {
            if ($Operation.Mode -eq 'delete') {
                return [pscustomobject]@{ ReturnToParent = $false }
            }

            continue
        }

        Write-GerberPipelineTagMutationTrace -Operation $Operation -EventName 'plan-ready' -Data @{
            CurrentTag = $CurrentTag
            NewTag     = $plan.NewTag
            MatchCount = @($plan.BuildList).Count
        }
        $planFlowResult = Invoke-GerberPipelineTagMutationPlanFlow -Context $Context -Plan $plan
        if (Test-GerberPipelineTagMutationBackRequested -PlanFlowResult $planFlowResult) {
            continue
        }

        return $planFlowResult
    }
}

function Get-GerberPipelineTagMutationPlanInputOrNull {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Operation,

        [Parameter(Mandatory)]
        [string]$CurrentTag
    )

    if ($Operation.Mode -eq 'delete') {
        return [pscustomobject]@{
            NewTag = $null
        }
    }

    $newTag = Read-GerberPipelineTagMutationNewTagOrNull -Operation $Operation -CurrentTag $CurrentTag
    if ($null -eq $newTag) {
        return $null
    }

    Write-GerberPipelineTagMutationTrace -Operation $Operation -EventName 'new-tag' -Data @{
        CurrentTag = $CurrentTag
        NewTag     = $newTag
    }
    return [pscustomobject]@{
        NewTag = $newTag
    }
}

function Test-GerberPipelineTagMutationBackRequested {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$PlanFlowResult
    )

    if ($null -eq $PlanFlowResult) {
        return $false
    }

    if ($PlanFlowResult.PSObject.Properties.Name -notcontains 'BackRequested') {
        return $false
    }

    return [bool]$PlanFlowResult.BackRequested
}

function Invoke-GerberPipelineTagMutationPlanFlow {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [pscustomobject]$Plan
    )

    while ($true) {
        $selection = Read-GerberPipelineTagMutationSelectionOrNull -Plan $Plan
        if ($null -eq $selection) {
            return [pscustomobject]@{ BackRequested = $true }
        }

        if (-not (Confirm-GerberPipelineTagMutationApply -Plan $Plan -Selection $selection)) {
            continue
        }

        Write-GerberPromptTrace -EventName "$($Plan.TracePrefix)-apply-start" -Data @{
            CurrentTag    = $Plan.CurrentTag
            NewTag        = $Plan.NewTag
            SelectedCount = @($selection.SelectedBuildList).Count
        }
        $applyResult = Invoke-GerberPipelineTagMutationApply `
            -ApplyRequest ([pscustomobject]@{
                Configuration = $Context.Configuration
                Pat           = $Context.Pat
                Plan          = $Plan
                Selection     = $selection
            })
        return Show-GerberPipelineTagMutationApplyResult -ApplyResult $applyResult
    }
}

function Read-GerberPipelineTagMutationCurrentTagOrNull {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Operation
    )

    try {
        $currentTag = Read-GerberCommand `
            -Prompt 'Current tag' `
            -SuggestionMode 'None' `
            -PromptContext (ConvertTo-GerberCommandPromptContext `
                -PromptHintText (Get-GerberPipelineTagMutationCurrentTagHintText -Operation $Operation) `
                -EmptyStateHintText 'Current tag | esc back')
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) {
            return $null
        }

        throw
    }

    if ([string]::IsNullOrWhiteSpace($currentTag)) {
        Show-GerberPipelineReleaseRecoverableError -Message 'Gerber needs the current tag before it can continue.'
        return Read-GerberPipelineTagMutationCurrentTagOrNull -Operation $Operation
    }

    return [string]$currentTag
}

function Get-GerberPipelineTagMutationCurrentTagHintText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Operation
    )

    if ($Operation.Mode -eq 'delete') {
        return 'Enter the tag that Gerber should delete from existing pipeline runs.'
    }

    return 'Enter the tag that Gerber should replace on existing pipeline runs.'
}

function Read-GerberPipelineTagMutationNewTagOrNull {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Operation,

        [Parameter(Mandatory)]
        [string]$CurrentTag
    )

    try {
        $newTag = Read-GerberCommand `
            -Prompt 'New tag' `
            -SuggestionMode 'None' `
            -PromptContext (ConvertTo-GerberCommandPromptContext `
                -PromptHintText "Replace '$CurrentTag' with the new tag value." `
                -EmptyStateHintText 'New tag | esc back')
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) {
            return $null
        }

        throw
    }

    if ([string]::IsNullOrWhiteSpace($newTag)) {
        Show-GerberPipelineReleaseRecoverableError -Message 'Gerber needs the new tag before it can continue.'
        return Read-GerberPipelineTagMutationNewTagOrNull -Operation $Operation -CurrentTag $CurrentTag
    }

    if ([string]::Equals($CurrentTag, $newTag, [System.StringComparison]::OrdinalIgnoreCase)) {
        Show-GerberPipelineReleaseRecoverableError -Message 'Gerber needs a different new tag so the update changes the selected pipeline runs.'
        return Read-GerberPipelineTagMutationNewTagOrNull -Operation $Operation -CurrentTag $CurrentTag
    }

    return [string]$newTag
}

function Get-GerberPipelineTagMutationPlanOrNull {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [pscustomobject]$Operation,

        [Parameter(Mandatory)]
        [string]$CurrentTag,

        [AllowNull()]
        [string]$NewTag
    )

    Show-GerberPipelineReleaseLoadingScreen `
        -CommandLabel $Operation.CommandLabel `
        -Text "Finding pipeline runs tagged '$CurrentTag'..."
    try {
        $buildList = @(Get-GerberAdoBuildListByTag `
                -Configuration $Context.Configuration `
                -Pat $Context.Pat `
                -Tag $CurrentTag |
                Sort-Object DefinitionName, @{ Expression = { $_.QueueTime }; Descending = $true }, BuildId)
    } catch {
        Write-GerberPipelineTagMutationTrace -Operation $Operation -EventName 'plan-error' -Data @{
            CurrentTag = $CurrentTag
            NewTag     = $NewTag
            Message    = $_.Exception.Message
        }
        Show-GerberPipelineReleaseRecoverableError -Message $_.Exception.Message
        return $null
    }

    if ($buildList.Count -eq 0) {
        Write-GerberPipelineTagMutationTrace -Operation $Operation -EventName 'plan-empty' -Data @{
            CurrentTag = $CurrentTag
            NewTag     = $NewTag
        }
        Show-GerberPipelineReleaseRecoverableError -Message "Gerber could not find any pipeline runs tagged '$CurrentTag'."
        return $null
    }

    return [pscustomobject]@{
        Mode         = $Operation.Mode
        CommandLabel = $Operation.CommandLabel
        TracePrefix  = $Operation.TracePrefix
        CurrentTag   = $CurrentTag
        NewTag       = $NewTag
        BuildList    = $buildList
    }
}

function Read-GerberPipelineTagMutationSelectionOrNull {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Plan
    )

    try {
        $checkboxResult = Read-GerberCheckboxMenuPrompt `
            -PromptRequest ([pscustomobject]@{
                Prompt                = 'Tagged runs'
                ScreenTitle           = $Plan.CommandLabel
                ScreenText            = Get-GerberPipelineTagMutationSelectionText -Plan $Plan
                ItemList              = @(Get-GerberPipelineTagMutationCheckboxItemList -Plan $Plan)
                EmptySelectionMessage = 'Select at least one tagged pipeline run before Apply.'
            })
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) {
            return $null
        }

        throw
    }

    return ConvertTo-GerberPipelineTagMutationSelection -CheckboxResult $checkboxResult
}

function Get-GerberPipelineTagMutationCheckboxItemList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Plan
    )

    return @(
        foreach ($build in $Plan.BuildList) {
            [pscustomobject]@{
                Label       = Get-GerberPipelineTagMutationCheckboxLabel -Build $build
                Description = ''
                Value       = $build.BuildId
                Build       = $build
            }
        }
    )
}

function Get-GerberPipelineTagMutationCheckboxLabel {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Build
    )

    return "$($Build.DefinitionName) / $($Build.BuildNumber) | BuildId: $($Build.BuildId) | Queued: $($Build.QueueTimeText) | Status: $(Get-GerberPipelineTagMutationBuildStatusText -Build $Build)"
}

function Get-GerberPipelineTagMutationBuildStatusText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Build
    )

    $status = if ([string]::IsNullOrWhiteSpace([string]$Build.Status)) { 'unknown' } else { [string]$Build.Status }
    $result = if ([string]::IsNullOrWhiteSpace([string]$Build.Result)) { '' } else { "/$($Build.Result)" }
    return "$status$result"
}

function ConvertTo-GerberPipelineTagMutationSelection {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$CheckboxResult
    )

    $selectedBuildList = @(
        foreach ($item in $CheckboxResult.SelectedItemList) {
            $item.Build
        }
    )
    $excludedBuildList = @(
        foreach ($item in $CheckboxResult.DeselectedItemList) {
            $item.Build
        }
    )

    return [pscustomobject]@{
        SelectedBuildList = $selectedBuildList
        ExcludedBuildList = $excludedBuildList
    }
}

function Get-GerberPipelineTagMutationSelectionText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Plan
    )

    $pipelineGroupList = @($Plan.BuildList | Group-Object DefinitionName | Sort-Object Name)
    $lineList = [System.Collections.Generic.List[string]]::new()
    $lineList.Add("Current tag: $($Plan.CurrentTag)")
    if ($Plan.Mode -eq 'update') {
        $lineList.Add("New tag: $($Plan.NewTag)")
    }
    $lineList.Add("Matching runs: $(@($Plan.BuildList).Count)")
    $lineList.Add('')
    $lineList.Add('Pipelines with matching runs')
    foreach ($group in $pipelineGroupList) {
        $lineList.Add("- $($group.Name) ($($group.Count))")
    }

    return $lineList -join [Environment]::NewLine
}

function Confirm-GerberPipelineTagMutationApply {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Plan,

        [Parameter(Mandatory)]
        [pscustomobject]$Selection
    )

    try {
        return Read-GerberConfirmationPrompt `
            -Prompt 'Confirm' `
            -ScreenTitle $Plan.CommandLabel `
            -ScreenText (Get-GerberPipelineTagMutationConfirmationText -Plan $Plan -Selection $Selection) `
            -PromptOptionSet (Get-GerberConfirmationPromptOptionSet `
                -ActionLabel 'Apply' `
                -CancelLabel 'Cancel' `
                -ActionPreviewText (Get-GerberPipelineTagMutationApplyPreviewText -Plan $Plan -Selection $Selection) `
                -CancelPreviewText 'Cancel and return to the tagged run selection.' `
                -DefaultOption 'cancel')
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) {
            return $false
        }

        throw
    }
}

function Get-GerberPipelineTagMutationConfirmationText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Plan,

        [Parameter(Mandatory)]
        [pscustomobject]$Selection
    )

    $lineList = [System.Collections.Generic.List[string]]::new()
    $lineList.Add((Get-GerberPipelineTagMutationConfirmationIntro -Plan $Plan))
    $lineList.Add('')
    foreach ($line in @(Get-GerberPipelineTagMutationBuildSectionLineList `
                -Heading 'Apply to' `
                -ItemList $Selection.SelectedBuildList `
                -ItemTextScript { param($build) "- $($build.DefinitionName) / $($build.BuildNumber)" })) {
        $lineList.Add($line)
    }
    if (@($Selection.ExcludedBuildList).Count -gt 0) {
        $lineList.Add('')
        foreach ($line in @(Get-GerberPipelineTagMutationBuildSectionLineList `
                    -Heading 'Skip' `
                    -ItemList $Selection.ExcludedBuildList `
                    -ItemTextScript { param($build) "- $($build.DefinitionName) / $($build.BuildNumber)" })) {
            $lineList.Add($line)
        }
    }

    return $lineList -join [Environment]::NewLine
}

function Get-GerberPipelineTagMutationConfirmationIntro {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Plan
    )

    if ($Plan.Mode -eq 'delete') {
        return "Delete tag '$($Plan.CurrentTag)' from the selected pipeline runs."
    }

    return "Replace tag '$($Plan.CurrentTag)' with '$($Plan.NewTag)' on the selected pipeline runs."
}

function Get-GerberPipelineTagMutationBuildSectionLineList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Heading,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$ItemList,

        [Parameter(Mandatory)]
        [scriptblock]$ItemTextScript
    )

    return @(
        $Heading
        foreach ($item in $ItemList) {
            & $ItemTextScript $item
        }
    )
}

function Get-GerberPipelineTagMutationApplyPreviewText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Plan,

        [Parameter(Mandatory)]
        [pscustomobject]$Selection
    )

    if ($Plan.Mode -eq 'delete') {
        return "Delete tag '$($Plan.CurrentTag)' from $(@($Selection.SelectedBuildList).Count) selected pipeline run(s)."
    }

    return "Update $(@($Selection.SelectedBuildList).Count) selected pipeline run(s) from '$($Plan.CurrentTag)' to '$($Plan.NewTag)'."
}

function Invoke-GerberPipelineTagMutationApply {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$ApplyRequest
    )

    $changedBuildList = [System.Collections.Generic.List[object]]::new()
    $failedBuildList = [System.Collections.Generic.List[object]]::new()
    foreach ($build in $ApplyRequest.Selection.SelectedBuildList) {
        try {
            Invoke-GerberPipelineTagMutationBuild `
                -Configuration $ApplyRequest.Configuration `
                -Pat $ApplyRequest.Pat `
                -Build $build `
                -Plan $ApplyRequest.Plan
            $changedBuildList.Add($build)
        } catch {
            $failedBuildList.Add((ConvertTo-GerberPipelineTagMutationFailure `
                    -Build $build `
                    -Plan $ApplyRequest.Plan `
                    -Message $_.Exception.Message))
        }
    }

    return [pscustomobject]@{
        Plan              = $ApplyRequest.Plan
        ChangedBuildList  = @($changedBuildList)
        FailedBuildList   = @($failedBuildList)
        ExcludedBuildList = @($ApplyRequest.Selection.ExcludedBuildList)
    }
}

function Invoke-GerberPipelineTagMutationBuild {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [pscustomobject]$Build,

        [Parameter(Mandatory)]
        [pscustomobject]$Plan
    )

    Remove-GerberAdoBuildTag `
        -Configuration $Configuration `
        -Pat $Pat `
        -BuildId $Build.BuildId `
        -Tag $Plan.CurrentTag
    if ($Plan.Mode -eq 'update') {
        Add-GerberAdoBuildTag `
            -Configuration $Configuration `
            -Pat $Pat `
            -BuildId $Build.BuildId `
            -Tag $Plan.NewTag
    }
}

function ConvertTo-GerberPipelineTagMutationFailure {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Build,

        [Parameter(Mandatory)]
        [pscustomobject]$Plan,

        [Parameter(Mandatory)]
        [string]$Message
    )

    return [pscustomobject]@{
        Build       = $Build
        ErrorDetail = Get-GerberPipelineTagMutationFailureMessage -Build $Build -Plan $Plan -Message $Message
    }
}

function Get-GerberPipelineTagMutationFailureMessage {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Build,

        [Parameter(Mandatory)]
        [pscustomobject]$Plan,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if ($Plan.Mode -eq 'delete') {
        return "Could not delete tag '$($Plan.CurrentTag)' from BuildId $($Build.BuildId). $Message"
    }

    return "Could not replace tag '$($Plan.CurrentTag)' with '$($Plan.NewTag)' on BuildId $($Build.BuildId). $Message"
}

function Show-GerberPipelineTagMutationApplyResult {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$ApplyResult
    )

    Show-GerberTextBlock `
        -Title $ApplyResult.Plan.CommandLabel `
        -Text (Get-GerberPipelineTagMutationApplyResultText -ApplyResult $ApplyResult)
    Write-GerberPromptTrace -EventName "$($ApplyResult.Plan.TracePrefix)-apply-result" -Data @{
        ChangedCount = @($ApplyResult.ChangedBuildList).Count
        FailedCount  = @($ApplyResult.FailedBuildList).Count
        SkippedCount = @($ApplyResult.ExcludedBuildList).Count
    }
    try {
        Wait-GerberContinue
        return [pscustomobject]@{ ReturnToParent = $false }
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) {
            return [pscustomobject]@{ ReturnToParent = $true }
        }

        throw
    }
}

function Get-GerberPipelineTagMutationApplyResultText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$ApplyResult
    )

    $lineList = [System.Collections.Generic.List[string]]::new()
    $lineList.Add("Current tag: $($ApplyResult.Plan.CurrentTag)")
    if ($ApplyResult.Plan.Mode -eq 'update') {
        $lineList.Add("New tag: $($ApplyResult.Plan.NewTag)")
    }
    $lineList.Add("$(Get-GerberPipelineTagMutationChangedSummaryLabel -Plan $ApplyResult.Plan): $(@($ApplyResult.ChangedBuildList).Count)")
    $lineList.Add("Failed: $(@($ApplyResult.FailedBuildList).Count)")
    $lineList.Add("Skipped: $(@($ApplyResult.ExcludedBuildList).Count)")
    foreach ($line in @(Get-GerberPipelineTagMutationBuildSectionLineList `
                -Heading (Get-GerberPipelineTagMutationChangedSectionHeading -Plan $ApplyResult.Plan) `
                -ItemList $ApplyResult.ChangedBuildList `
                -ItemTextScript { param($build) "- $($build.DefinitionName) / $($build.BuildNumber) -> $($build.RunUrl)" })) {
        $lineList.Add($line)
    }
    foreach ($line in @(Get-GerberPipelineTagMutationFailureSectionLineList -ApplyResult $ApplyResult)) {
        $lineList.Add($line)
    }

    return $lineList -join [Environment]::NewLine
}

function Get-GerberPipelineTagMutationChangedSummaryLabel {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Plan
    )

    if ($Plan.Mode -eq 'delete') {
        return 'Deleted'
    }

    return 'Updated'
}

function Get-GerberPipelineTagMutationChangedSectionHeading {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Plan
    )

    if ($Plan.Mode -eq 'delete') {
        return 'Deleted now'
    }

    return 'Updated now'
}

function Get-GerberPipelineTagMutationFailureSectionLineList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$ApplyResult
    )

    if (@($ApplyResult.FailedBuildList).Count -eq 0) {
        return @()
    }

    return @(
        ''
        $(if ($ApplyResult.Plan.Mode -eq 'delete') { 'Failed to delete' } else { 'Failed to update' })
        foreach ($failure in $ApplyResult.FailedBuildList) {
            "- $($failure.Build.DefinitionName) / $($failure.Build.BuildNumber): $($failure.ErrorDetail)"
        }
    )
}
