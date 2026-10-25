function Invoke-GerberBranchSetDefaultFlow {
    [CmdletBinding()]
    param()

    while ($true) {
        Show-GerberBranchSetDefaultHeader
        $branchInput = Read-GerberSetDefaultBranchNameOrNull
        if ($null -eq $branchInput) { return }
        $shouldContinue = Invoke-GerberSetDefaultIteration -BranchInput $branchInput
        if (-not $shouldContinue) { return }
    }
}

function Invoke-GerberSetDefaultIteration {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BranchInput
    )

    $context = Build-GerberSetDefaultContext -BranchInput $BranchInput
    $report = Get-GerberAdoDefaultBranchReport -Context $context
    if ($report.ToUpdateList.Count -eq 0) {
        Show-GerberSetDefaultNoOpResult -Report $report
        return Wait-GerberSetDefaultContinue
    }
    $confirmed = Confirm-GerberSetDefaultApply -Report $report
    Write-GerberPromptTrace -EventName 'set-default-confirmed' -Data @{ Confirmed = $confirmed }
    if (-not $confirmed) { return $true }
    Show-GerberBranchSetDefaultApplyScreen
    $results = Invoke-GerberSetDefaultApplyWithProgress -Context $context -Report $report
    Write-GerberPromptTrace -EventName 'set-default-apply-done' -Data @{ ResultCount = $results.Results.Count }
    Show-GerberSetDefaultApplyResult -Results $results
    Write-GerberPromptTrace -EventName 'set-default-result-shown' -Data @{}
    return Wait-GerberSetDefaultContinue
}

function Show-GerberBranchSetDefaultHeader {
    [CmdletBinding()]
    param()

    Start-GerberScreen -Name '/branch set-default'
    Write-GerberScreenLine -Text '/branch set-default'
    Write-GerberScreenLine
}

function Show-GerberBranchSetDefaultApplyScreen {
    [CmdletBinding()]
    param()

    Start-GerberScreen -Name '/branch set-default'
    Write-GerberScreenLine -Text '/branch set-default'
    Write-GerberScreenLine
}

function Read-GerberSetDefaultBranchNameOrNull {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    try {
        return Read-GerberCommand -Prompt 'Branch name' -SuggestionMode 'None'
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) {
            return $null
        }
        throw
    }
}

function Build-GerberSetDefaultContext {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BranchInput
    )

    $configuration = Get-GerberAdoConfiguration
    $pat = Resolve-GerberAdoPat -Configuration $configuration
    $targetBranch = ConvertTo-GerberNormalizedBranchPath -BranchPath $BranchInput
    return [pscustomobject]@{
        Configuration = $configuration
        Pat           = $pat
        TargetBranch  = $targetBranch
    }
}

function Show-GerberSetDefaultNoOpResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Report
    )

    Start-GerberScreen -Name '/branch set-default'
    Write-GerberScreenLine -Text '/branch set-default'
    Write-GerberScreenLine
    if ($Report.NotFoundList.Count -eq 0) {
        Write-GerberScreenLine -Text "All $($Report.AlreadyAlignedList.Count) repositories are already on target."
        return
    }
    Write-GerberSearchableBranchPreviewGroup -Label "Branch not found ($($Report.NotFoundList.Count))" -Items $Report.NotFoundList
    $alignedCount = $Report.AlreadyAlignedList.Count
    $notFoundCount = $Report.NotFoundList.Count
    Write-GerberScreenLine -Text "$alignedCount already on target, $notFoundCount branch not found (skipped). No changes needed."
}

function Show-GerberSetDefaultPreview {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Report
    )

    Start-GerberScreen -Name '/branch set-default'
    Write-GerberScreenLine -Text '/branch set-default'
    Write-GerberScreenLine
    Write-GerberSearchableBranchPreviewGroup -Label "To update ($($Report.ToUpdateList.Count))" -Items $Report.ToUpdateList
    Write-GerberSearchableBranchPreviewGroup -Label "Already on target ($($Report.AlreadyAlignedList.Count))" -Items $Report.AlreadyAlignedList
    Write-GerberSearchableBranchPreviewGroup -Label "Branch not found ($($Report.NotFoundList.Count))" -Items $Report.NotFoundList
}

function Confirm-GerberSetDefaultApply {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Report
    )

    $optionSet = Get-GerberConfirmationPromptOptionSet `
        -ActionLabel 'Apply' `
        -CancelLabel 'Cancel' `
        -ActionPreviewText 'Apply the default branch change to all qualifying repositories.' `
        -CancelPreviewText 'Cancel and return to branch name input.'
    Show-GerberSetDefaultPreview -Report $Report
    try {
        return Read-GerberConfirmationPrompt -Prompt 'Confirm' -PromptOptionSet $optionSet
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) {
            return $false
        }
        throw
    }
}

function Invoke-GerberSetDefaultApplyWithProgress {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [pscustomobject]$Report
    )

    $total = $Report.ToUpdateList.Count
    $index = 0
    $resultList = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($item in $Report.ToUpdateList) {
        $index++
        Write-GerberProgressBar -Current $index -Total $total -Prefix 'Applying...'
        $null = $resultList.Add((Set-GerberAdoRepositoryDefaultBranch -Context $Context -RepoItem $item))
    }
    return [pscustomobject]@{
        Results        = @($resultList)
        UnchangedCount = $Report.AlreadyAlignedList.Count
        NotFoundCount  = $Report.NotFoundList.Count
    }
}

function Show-GerberSetDefaultApplyResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Results
    )

    Start-GerberScreen -Name '/branch set-default'
    Write-GerberScreenLine -Text '/branch set-default'
    Write-GerberScreenLine
    $updated = @($Results.Results | Where-Object { $_.Success })
    $failed  = @($Results.Results | Where-Object { -not $_.Success })
    Write-GerberSetDefaultResultSummary `
        -Updated $updated `
        -Unchanged $Results.UnchangedCount `
        -NotFound $Results.NotFoundCount `
        -Failed $failed
}

function Write-GerberSetDefaultResultSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Updated,

        [Parameter(Mandatory)]
        [int]$Unchanged,

        [Parameter(Mandatory)]
        [int]$NotFound,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Failed
    )

    foreach ($item in $Updated) { Write-GerberScreenLine -Text "  [+] $($item.RepoName)" }
    foreach ($item in $Failed)  { Write-GerberScreenLine -Text "  [!] $($item.RepoName)" }
    Write-GerberScreenLine
    Write-GerberScreenLine -Text "Updated $($Updated.Count)  Already on target $Unchanged  Not found (skipped) $NotFound  Failed $($Failed.Count)"
}

function Wait-GerberSetDefaultContinue {
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
