function Invoke-GerberBranchSetSearchableFlow {
    [CmdletBinding()]
    param()

    while ($true) {
        Show-GerberBranchSetSearchableHeader
        $branchInput = Read-GerberSearchableBranchNamesInputOrNull
        if ($null -eq $branchInput) { return }
        $shouldContinue = Invoke-GerberSearchableBranchIteration -BranchInput $branchInput
        if (-not $shouldContinue) { return }
    }
}

function Invoke-GerberSearchableBranchIteration {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BranchInput
    )

    $mode = Read-GerberSearchableBranchModeOrNull
    if ($null -eq $mode) { return $true }
    $context = Build-GerberSearchableBranchContext -BranchInput $BranchInput -Mode $mode
    $report = Get-GerberAdoSearchableBranchPolicyReport -Context $context
    $changeCount = Get-GerberSearchableBranchChangeCount -Report $report
    Write-GerberPromptTrace -EventName 'set-searchable-change-count' -Data @{ ChangeCount = $changeCount; CreateCount = $report.CreateList.Count; UpdateCount = $report.UpdateList.Count }
    if ($changeCount -eq 0) {
        Show-GerberSearchableBranchNoOpResult -Report $report
        return Wait-GerberSearchableBranchContinue
    }
    $confirmed = Confirm-GerberSearchableBranchApply -Report $report
    Write-GerberPromptTrace -EventName 'set-searchable-confirmed' -Data @{ Confirmed = $confirmed }
    if (-not $confirmed) { return $true }
    Show-GerberSearchableBranchApplyScreen
    $results = Invoke-GerberSearchableBranchApplyWithProgress -Context $context -Report $report
    Write-GerberPromptTrace -EventName 'set-searchable-apply-done' -Data @{ ResultCount = $results.Results.Count; UnchangedCount = $results.UnchangedCount }
    Show-GerberSearchableBranchApplyResult -Results $results
    Write-GerberPromptTrace -EventName 'set-searchable-result-shown' -Data @{}
    return Wait-GerberSearchableBranchContinue
}

function Show-GerberBranchSetSearchableHeader {
    [CmdletBinding()]
    param()

    Start-GerberScreen -Name '/branch set-searchable'
    Write-GerberScreenLine -Text '/branch set-searchable'
    Write-GerberScreenLine
}

function Show-GerberSearchableBranchApplyScreen {
    [CmdletBinding()]
    param()

    Start-GerberScreen -Name '/branch set-searchable'
    Write-GerberScreenLine -Text '/branch set-searchable'
    Write-GerberScreenLine
}

function Read-GerberSearchableBranchNamesInputOrNull {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    try {
        return Read-GerberCommand -Prompt 'Branch names (comma-separated)' -SuggestionMode 'None'
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) {
            return $null
        }
        throw
    }
}

function Read-GerberSearchableBranchModeOrNull {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    try {
        return Read-GerberNumberedMenuPrompt `
            -Prompt 'Mode' `
            -MenuItemList (Get-GerberSearchableBranchModeMenuItemList)
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) {
            return $null
        }
        throw
    }
}

function Get-GerberSearchableBranchModeMenuItemList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param()

    return @(
        [pscustomobject]@{
            Number      = 1
            Label       = 'Replace existing policy'
            Value       = 'Replace'
            PreviewText = 'Replace the existing searchable-branches policy scope with the specified branches.'
        }
        [pscustomobject]@{
            Number      = 2
            Label       = 'Merge with existing policy'
            Value       = 'Merge'
            PreviewText = 'Merge the specified branches into the existing searchable-branches policy scope.'
        }
    )
}

function Build-GerberSearchableBranchContext {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BranchInput,

        [Parameter(Mandatory)]
        [string]$Mode
    )

    $configuration = Get-GerberAdoConfiguration
    $pat = Resolve-GerberAdoPat -Configuration $configuration
    $desiredBranchList = @(
        $BranchInput -split ',' |
            ForEach-Object { ConvertTo-GerberNormalizedBranchPath -BranchPath $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
    return [pscustomobject]@{
        Configuration     = $configuration
        Pat               = $pat
        DesiredBranchList = $desiredBranchList
        Mode              = $Mode
    }
}

function Get-GerberSearchableBranchChangeCount {
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Report
    )

    return $Report.CreateList.Count + $Report.UpdateList.Count
}

function Show-GerberSearchableBranchNoOpResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Report
    )

    Start-GerberScreen -Name '/branch set-searchable'
    Write-GerberScreenLine -Text '/branch set-searchable'
    Write-GerberScreenLine
    Write-GerberScreenLine -Text "All $($Report.AlreadyAlignedList.Count) repositories are already aligned."
}

function Show-GerberSearchableBranchPreview {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Report
    )

    Start-GerberScreen -Name '/branch set-searchable'
    Write-GerberScreenLine -Text '/branch set-searchable'
    Write-GerberScreenLine
    Write-GerberSearchableBranchPreviewGroup -Label "To create ($($Report.CreateList.Count))" -Items $Report.CreateList
    Write-GerberSearchableBranchPreviewGroup -Label "To update ($($Report.UpdateList.Count))" -Items $Report.UpdateList
    Write-GerberSearchableBranchPreviewGroup -Label "Already aligned ($($Report.AlreadyAlignedList.Count))" -Items $Report.AlreadyAlignedList
}

function Write-GerberSearchableBranchPreviewGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Items
    )

    if ($Items.Count -eq 0) { return }
    $maxItems = 8
    Write-GerberScreenLine -Text $Label
    foreach ($item in ($Items | Select-Object -First $maxItems)) {
        Write-GerberScreenLine -Text "  $($item.RepoName)"
    }
    if ($Items.Count -gt $maxItems) {
        Write-GerberScreenLine -Text "  ... and $($Items.Count - $maxItems) more"
    }
    Write-GerberScreenLine
}

function Confirm-GerberSearchableBranchApply {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Report
    )

    $optionSet = Get-GerberConfirmationPromptOptionSet `
        -ActionLabel 'Apply' `
        -CancelLabel 'Cancel' `
        -ActionPreviewText 'Apply the policy changes to all repositories.' `
        -CancelPreviewText 'Cancel and return to branch name input.'
    Show-GerberSearchableBranchPreview -Report $Report
    try {
        return Read-GerberConfirmationPrompt -Prompt 'Confirm' -PromptOptionSet $optionSet
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) {
            return $false
        }
        throw
    }
}

function Invoke-GerberSearchableBranchApplyWithProgress {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [pscustomobject]$Report
    )

    $workList = @($Report.CreateList) + @($Report.UpdateList)
    $total = $workList.Count
    $index = 0
    $resultList = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($item in $workList) {
        $index++
        Write-GerberProgressBar -Current $index -Total $total -Prefix 'Applying...'
        $null = $resultList.Add((Set-GerberAdoSearchableBranchPolicy -Context $Context -PolicyItem $item))
    }
    return [pscustomobject]@{ Results = @($resultList); UnchangedCount = $Report.AlreadyAlignedList.Count }
}

function Show-GerberSearchableBranchApplyResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Results
    )

    Start-GerberScreen -Name '/branch set-searchable'
    Write-GerberScreenLine -Text '/branch set-searchable'
    Write-GerberScreenLine
    $created = @($Results.Results | Where-Object { $_.Success -and $_.IsCreate })
    $updated = @($Results.Results | Where-Object { $_.Success -and -not $_.IsCreate })
    $failed = @($Results.Results | Where-Object { -not $_.Success })
    Write-GerberSearchableBranchResultSummary `
        -Created $created -Updated $updated `
        -Unchanged $Results.UnchangedCount -Failed $failed
}

function Write-GerberSearchableBranchResultSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Created,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Updated,

        [Parameter(Mandatory)]
        [int]$Unchanged,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Failed
    )

    foreach ($item in $Created) { Write-GerberScreenLine -Text "  [+] $($item.RepoName)" }
    foreach ($item in $Updated) { Write-GerberScreenLine -Text "  [+] $($item.RepoName)" }
    foreach ($item in $Failed)  { Write-GerberScreenLine -Text "  [!] $($item.RepoName)" }
    Write-GerberScreenLine
    Write-GerberScreenLine -Text "Created $($Created.Count)  Updated $($Updated.Count)  Unchanged $Unchanged  Failed $($Failed.Count)"
}

function Wait-GerberSearchableBranchContinue {
    [OutputType([bool])]
    [CmdletBinding()]
    param()

    try {
        Wait-GerberContinue
        return $true
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) {
            return $false
        }
        throw
    }
}
