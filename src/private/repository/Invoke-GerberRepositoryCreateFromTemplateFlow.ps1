function Invoke-GerberRepositoryCreateFromTemplateFlow {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$ProjectSelection,

        [Parameter(Mandatory)]
        [pscustomobject]$TemplateSelection
    )
    $null = $PSCmdlet.ShouldProcess('Invoke-GerberRepositoryCreateFromTemplateFlow', 'Invoke')

    Show-GerberRepositoryCreateFromTemplateHeader
    return Invoke-GerberRepositoryCreateFromTemplateIteration -ProjectSelection $ProjectSelection -TemplateSelection $TemplateSelection
}

function Invoke-GerberRepositoryCreateFromTemplateIteration {
    [OutputType([bool])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$ProjectSelection,

        [Parameter(Mandatory)]
        [pscustomobject]$TemplateSelection
    )
    $null = $PSCmdlet.ShouldProcess('Invoke-GerberRepositoryCreateFromTemplateIteration', 'Invoke')

    Write-GerberPromptTrace -EventName 'create-repository-project-selected' -Data @{ ProjectName = $ProjectSelection.Name }
    Write-GerberPromptTrace -EventName 'create-repository-template-selected' -Data @{ TemplateName = $TemplateSelection.Name }
    $repositoryNameInput = Read-GerberRepositoryCreateRepositoryNameOrNull
    if ($null -eq $repositoryNameInput) { return $true }
    Write-GerberPromptTrace -EventName 'create-repository-name-entered' -Data @{ RepositoryName = $repositoryNameInput }
    $teamSelection = Read-GerberRepositoryCreateTeamOrNull -ProjectSelection $ProjectSelection
    if ($null -eq $teamSelection) { return $true }
    Write-GerberPromptTrace -EventName 'create-repository-team-selected' -Data @{ TeamName = $teamSelection.Name }
    $context = Build-GerberRepositoryCreateContext -ProjectSelection $ProjectSelection -TemplateSelection $templateSelection -RepositoryName $repositoryNameInput -TeamSelection $teamSelection
    Show-GerberRepositoryCreatePreview -Context $context
    Write-GerberPromptTrace -EventName 'create-repository-preview-shown' -Data @{}
    $confirmed = Confirm-GerberRepositoryCreateApply
    Write-GerberPromptTrace -EventName 'create-repository-confirmed' -Data @{ Confirmed = $confirmed }
    if (-not $confirmed) { return $true }
    Show-GerberRepositoryCreateApplyScreen
    $results = Invoke-GerberRepositoryCreateApplyWithProgress -Context $context
    Write-GerberPromptTrace -EventName 'create-repository-apply-done' -Data @{ Success = ($results.Failures.Count -eq 0) }
    Show-GerberRepositoryCreateApplyResult -Results $results
    Write-GerberPromptTrace -EventName 'create-repository-result-shown' -Data @{}
    return Wait-GerberRepositoryCreateContinue
}

function Show-GerberRepositoryCreateFromTemplateHeader {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('Show-GerberRepositoryCreateFromTemplateHeader', 'Invoke')

    Start-GerberScreen -Name '/repository create'
    Write-GerberScreenLine -Text '/repository create'
    Write-GerberScreenLine
}

function Read-GerberRepositoryCreateRepositoryNameOrNull {
    [OutputType([string])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('Read-GerberRepositoryCreateRepositoryNameOrNull', 'Invoke')

    try {
        return Read-GerberCommand -Prompt 'Repository name' -SuggestionMode 'None'
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) {
            return $null
        }
        throw
    }
}

function Read-GerberRepositoryCreateTeamOrNull {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$ProjectSelection
    )
    $null = $PSCmdlet.ShouldProcess('Read-GerberRepositoryCreateTeamOrNull', 'Invoke')

    $configuration = Get-GerberAdoConfiguration
    $pat = Resolve-GerberAdoPat -Configuration $configuration
    $teamList = @(Get-GerberAdoTeamList -Configuration $configuration -Pat $pat -ProjectId $ProjectSelection.Id)
    $menuItems = @(Convert-GerberListToNumberedMenuItemList -ItemList $teamList -DisplayProperty 'Name')
    try {
        $selection = Read-GerberNumberedMenuPrompt -Prompt 'Owner team' -MenuItemList $menuItems
        return $teamList | Where-Object { $_.Name -eq $selection } | Select-Object -First 1
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) {
            return $null
        }
        throw
    }
}

function Build-GerberRepositoryCreateContext {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$ProjectSelection,

        [Parameter(Mandatory)]
        [pscustomobject]$TemplateSelection,

        [Parameter(Mandatory)]
        [string]$RepositoryName,

        [Parameter(Mandatory)]
        [pscustomobject]$TeamSelection
    )
    $null = $PSCmdlet.ShouldProcess('Build-GerberRepositoryCreateContext', 'Invoke')

    $configuration = Get-GerberAdoConfiguration
    $pat = Resolve-GerberAdoPat -Configuration $configuration
    return [pscustomobject]@{
        Configuration     = $configuration
        Pat               = $pat
        Project           = $ProjectSelection
        Template          = $TemplateSelection
        RepositoryName    = $RepositoryName
        Team              = $TeamSelection
    }
}

function Show-GerberRepositoryCreatePreview {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context
    )
    $null = $PSCmdlet.ShouldProcess('Show-GerberRepositoryCreatePreview', 'Invoke')

    Start-GerberScreen -Name '/repository create'
    Write-GerberScreenLine -Text '/repository create'
    Write-GerberScreenLine
    Write-GerberScreenLine -Text "Repository: $($Context.RepositoryName)"
    Write-GerberScreenLine -Text "Template:   $($Context.Template.Name)"
    Write-GerberScreenLine -Text "Owner team: $($Context.Team.Name)"
    Write-GerberScreenLine
}

function Confirm-GerberRepositoryCreateApply {
    [OutputType([bool])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('Confirm-GerberRepositoryCreateApply', 'Invoke')

    $optionSet = Get-GerberConfirmationPromptOptionSet `
        -ActionLabel 'Apply' `
        -CancelLabel 'Cancel' `
        -ActionPreviewText 'Create the repository and configure all settings.' `
        -CancelPreviewText 'Cancel and return to repository name input.'
    try {
        return Read-GerberConfirmationPrompt -Prompt 'Confirm' -PromptOptionSet $optionSet
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) {
            return $false
        }
        throw
    }
}

function Show-GerberRepositoryCreateApplyScreen {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('Show-GerberRepositoryCreateApplyScreen', 'Invoke')

    Start-GerberScreen -Name '/repository create'
    Write-GerberScreenLine -Text '/repository create'
    Write-GerberScreenLine
}

function Get-GerberRepositoryStepErrorDetail {
    [OutputType([string])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Result,

        [switch]$IncludeErrorDetail
    )
    $null = $PSCmdlet.ShouldProcess('Get-GerberRepositoryStepErrorDetail', 'Invoke')

    if (-not $IncludeErrorDetail) { return '' }
    $hasDetail = $Result.PSObject.Properties['ErrorDetail'] -and $Result.ErrorDetail
    if (-not $hasDetail) { return '' }
    return ": $($Result.ErrorDetail)"
}

function Invoke-GerberRepositoryCreateStep {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$Failures,

        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [pscustomobject]$Result,

        [switch]$IncludeErrorDetail
    )
    $null = $PSCmdlet.ShouldProcess('Invoke-GerberRepositoryCreateStep', 'Invoke')

    if ($Result.Success) { return }
    $detail = Get-GerberRepositoryStepErrorDetail -Result $Result -IncludeErrorDetail:$IncludeErrorDetail
    $null = $Failures.Add("$Label$detail")
}

function Invoke-GerberRepositoryCreateApplyWithProgress {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context
    )
    $null = $PSCmdlet.ShouldProcess('Invoke-GerberRepositoryCreateApplyWithProgress', 'Invoke')

    $steps = @('Create repository', 'Fetch files', 'Initial commit', 'Create pipelines', 'Create branches', 'Set default branch', 'Copy policies')
    $index = 0
    $total = $steps.Count
    $failures = [System.Collections.Generic.List[string]]::new()
    $index++
    Write-GerberProgressBar -Current $index -Total $total -Prefix 'Creating repository...'
    $repoResult = New-GerberAdoRepository -Context $Context
    if (-not $repoResult.Success) {
        $failureDetail = if ($repoResult.ErrorDetail) { ": $($repoResult.ErrorDetail)" } else { '' }
        $null = $failures.Add("Create repository$failureDetail")
        return [pscustomobject]@{
            Failures = @($failures)
        }
    }
    $index++
    Write-GerberProgressBar -Current $index -Total $total -Prefix 'Fetching template files...'
    $templateBranchName = $Context.Template.DefaultBranch -replace '^refs/heads/', ''
    $filesResult = Get-GerberAdoRepositoryItemTree -Context $Context -RepoId $Context.Template.Id -BranchName $templateBranchName
    Invoke-GerberRepositoryCreateStep -Failures $failures -Label 'Fetch files' -Result $filesResult -IncludeErrorDetail
    $index++
    Write-GerberProgressBar -Current $index -Total $total -Prefix 'Creating initial commit...'
    $commitResult = New-GerberAdoRepositoryInitialCommit -Context $Context -RepoId $repoResult.RepoId -FileTree $filesResult.FileTree -DefaultBranchRef $Context.Template.DefaultBranch
    Invoke-GerberRepositoryCreateStep -Failures $failures -Label 'Initial commit' -Result $commitResult -IncludeErrorDetail
    $index++
    Write-GerberProgressBar -Current $index -Total $total -Prefix 'Creating pipelines...'
    $pipelinesResult = New-GerberAdoPipelinesFromTemplate -Context $Context -RepoId $repoResult.RepoId -FileTree $filesResult.FileTree
    Invoke-GerberRepositoryCreateStep -Failures $failures -Label 'Create pipelines' -Result $pipelinesResult -IncludeErrorDetail
    $index++
    Write-GerberProgressBar -Current $index -Total $total -Prefix 'Creating branches...'
    $branchesResult = New-GerberAdoRepositoryBranchSet -Context $Context -RepoId $repoResult.RepoId
    Invoke-GerberRepositoryCreateStep -Failures $failures -Label 'Create branches' -Result $branchesResult -IncludeErrorDetail
    $index++
    Write-GerberProgressBar -Current $index -Total $total -Prefix 'Setting default branch...'
    $defaultBranchResult = Set-GerberAdoRepositoryCreateDefaultBranch -Context $Context -RepoId $repoResult.RepoId
    Invoke-GerberRepositoryCreateStep -Failures $failures -Label 'Set default branch' -Result $defaultBranchResult
    $index++
    Write-GerberProgressBar -Current $index -Total $total -Prefix 'Copying policies...'
    $policiesResult = Copy-GerberAdoPoliciesFromTemplate -Context $Context -RepoId $repoResult.RepoId -PipelineMap $pipelinesResult.PipelineMap
    Invoke-GerberRepositoryCreateStep -Failures $failures -Label 'Copy policies' -Result $policiesResult -IncludeErrorDetail
    return [pscustomobject]@{
        Failures = @($failures)
    }
}

function New-GerberAdoPipelinesFromTemplate {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [string]$RepoId,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$FileTree
    )
    $null = $PSCmdlet.ShouldProcess('New-GerberAdoPipelinesFromTemplate', 'Invoke')

    try {
        $pipelineMap = @{}
        $pipelineFiles = @(
            $FileTree |
                Where-Object { $_.gitObjectType -eq 'blob' -and $_.path -match '^/?pipelines/.*\.ya?ml$' } |
                ForEach-Object { $_.path }
        )
        $defaultBranchRef = $Context.Template.DefaultBranch
        foreach ($file in $pipelineFiles) {
            $result = New-GerberAdoPipeline `
                -Context $Context `
                -RepoId $RepoId `
                -YamlPath $file `
                -DefaultBranchRef $defaultBranchRef
            if (-not $result.Success) {
                throw $result.ErrorDetail
            }
            $pipelineMap[$result.YamlPath] = @{ Id = [int]$result.PipelineId; Name = $result.PipelineName }
        }
        return [pscustomobject]@{ Success = $true; PipelineMap = $pipelineMap }
    } catch {
        return [pscustomobject]@{ Success = $false; ErrorDetail = $_.Exception.Message; PipelineMap = @{} }
    }
}

function New-GerberAdoRepositoryBranchSet {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [string]$RepoId
    )
    $null = $PSCmdlet.ShouldProcess('New-GerberAdoRepositoryBranchSet', 'Invoke')

    try {
        $defaultBranchRef = $Context.Template.DefaultBranch
        $templateBranches = @(Get-GerberAdoRepositoryBranchList -Context $Context -RepoId $Context.Template.Id)
        foreach ($branch in $templateBranches) {
            if ($branch -ne $defaultBranchRef) {
                $null = New-GerberAdoRepositoryBranch -Context $Context -RepoId $RepoId -BranchRef $branch -DefaultBranchRef $defaultBranchRef
            }
        }
        return [pscustomobject]@{ Success = $true }
    } catch {
        return [pscustomobject]@{ Success = $false; ErrorDetail = $_.Exception.Message }
    }
}

function Set-GerberAdoRepositoryCreateDefaultBranch {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [string]$RepoId
    )
    $null = $PSCmdlet.ShouldProcess('Set-GerberAdoRepositoryCreateDefaultBranch', 'Invoke')

    try {
        if ($PSCmdlet.ShouldProcess($RepoId, 'Set default branch')) {
            $projectScope = Resolve-GerberAdoProjectScope -Context $Context
            $uri = Get-GerberAdoRepositoryPatchUri -Configuration $Context.Configuration -RepoId $RepoId -ProjectScope $projectScope
            $body = Build-GerberAdoRepositoryDefaultBranchBody -TargetBranch $Context.Template.DefaultBranch
            $mutationContext = [pscustomobject]@{
                Uri                     = $uri
                Pat                     = $Context.Pat
                Method                  = 'Patch'
                Body                    = $body
                RequestLabel            = 'default branch for new repository'
                CredentialIdentifier = $Context.Configuration.CredentialIdentifier
            }
            $null = Invoke-GerberAdoRestMutation -MutationContext $mutationContext
        }
        return [pscustomobject]@{ Success = $true }
    } catch {
        return [pscustomobject]@{ Success = $false; ErrorDetail = $_.Exception.Message }
    }
}

function Resolve-GerberBuildPolicyDisplayName {
    [OutputType([string])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [string]$TemplateDisplayName
    )
    $null = $PSCmdlet.ShouldProcess('Resolve-GerberBuildPolicyDisplayName', 'Invoke')

    $templateName = if ($Context.Template.PSObject.Properties['Name'] -and $Context.Template.Name) {
        [regex]::Escape($Context.Template.Name)
    } else { $null }
    if ($templateName) {
        return $TemplateDisplayName -replace $templateName, $Context.RepositoryName -replace 'PackageName', $Context.RepositoryName
    }
    return $TemplateDisplayName -replace 'PackageName', $Context.RepositoryName
}

function Copy-GerberAdoBuildValidationPolicy {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [string]$RepoId,

        [Parameter(Mandatory)]
        [pscustomobject]$Policy,

        [Parameter(Mandatory)]
        [hashtable]$PipelineMap
    )
    $null = $PSCmdlet.ShouldProcess('Copy-GerberAdoBuildValidationPolicy', 'Invoke')

    $pipelineDefResult = Get-GerberAdoPipelineDefinition -Context $Context -PipelineId ([int]$Policy.Settings.buildDefinitionId)
    if (-not $pipelineDefResult.Success) { return }
    $normalizedYamlPath = if ($pipelineDefResult.YamlPath.StartsWith('/')) { $pipelineDefResult.YamlPath } else { "/$($pipelineDefResult.YamlPath)" }
    if (-not $PipelineMap.ContainsKey($normalizedYamlPath)) { return }
    $newPipeline = $PipelineMap[$normalizedYamlPath]
    $resolvedPolicy = [pscustomobject]@{
        Id       = $Policy.Id
        Type     = $Policy.Type
        Settings = $Policy.Settings | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    }
    $resolvedPolicy.Settings.buildDefinitionId = $newPipeline.Id
    $resolvedPolicy.Settings.displayName = Resolve-GerberBuildPolicyDisplayName -Context $Context -TemplateDisplayName ([string]$Policy.Settings.displayName)
    $null = New-GerberAdoPolicyConfiguration -Context $Context -RepoId $RepoId -Policy $resolvedPolicy -TeamId $Context.Team.Id
}

function Add-GerberAdoRequiredReviewerPolicy {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [string]$RepoId,

        [Parameter(Mandatory)]
        [string]$RequiredReviewerTypeId
    )
    $null = $PSCmdlet.ShouldProcess('Add-GerberAdoRequiredReviewerPolicy', 'Invoke')

    $newRepoBranches = @(Get-GerberAdoRepositoryBranchList -Context $Context -RepoId $RepoId)
    foreach ($branchRef in $newRepoBranches) {
        $reviewerPolicy = [pscustomobject]@{
            Type     = [pscustomobject]@{ id = $RequiredReviewerTypeId }
            Settings = [pscustomobject]@{
                scope = @([pscustomobject]@{
                    refName   = $branchRef
                    matchKind = 'Exact'
                })
            }
        }
        $null = New-GerberAdoPolicyConfiguration -Context $Context -RepoId $RepoId -Policy $reviewerPolicy -TeamId $Context.Team.Id
    }
}

function Copy-GerberAdoPoliciesFromTemplate {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [string]$RepoId,

        [Parameter(Mandatory)]
        [hashtable]$PipelineMap
    )
    $null = $PSCmdlet.ShouldProcess('Copy-GerberAdoPoliciesFromTemplate', 'Invoke')

    try {
        $requiredReviewerTypeId = 'fd2167ab-b0be-447a-8ec8-39368250530e'
        $templatePolicies = @(Get-GerberAdoRepoPolicyList -Context $Context -RepoId $Context.Template.Id)
        foreach ($policy in $templatePolicies) {
            if ($policy.Type.id -eq $requiredReviewerTypeId) { continue }
            if ($policy.Settings.PSObject.Properties['buildDefinitionId']) {
                Copy-GerberAdoBuildValidationPolicy -Context $Context -RepoId $RepoId -Policy $policy -PipelineMap $PipelineMap
            } else {
                $null = New-GerberAdoPolicyConfiguration -Context $Context -RepoId $RepoId -Policy $policy -TeamId $Context.Team.Id
            }
        }
        Add-GerberAdoRequiredReviewerPolicy -Context $Context -RepoId $RepoId -RequiredReviewerTypeId $requiredReviewerTypeId
        return [pscustomobject]@{ Success = $true }
    } catch {
        return [pscustomobject]@{ Success = $false; ErrorDetail = $_.Exception.Message }
    }
}

function Show-GerberRepositoryCreateApplyResult {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Results
    )
    $null = $PSCmdlet.ShouldProcess('Show-GerberRepositoryCreateApplyResult', 'Invoke')

    Start-GerberScreen -Name '/repository create'
    Write-GerberScreenLine -Text '/repository create'
    Write-GerberScreenLine
    if ($Results.Failures.Count -eq 0) {
        Write-GerberScreenLine -Text 'Repository created successfully.'
    } else {
        Write-GerberScreenLine -Text "Repository created with $($Results.Failures.Count) failure(s):"
        foreach ($failure in $Results.Failures) {
            Write-GerberScreenLine -Text "  [!] $failure"
        }
    }
    Write-GerberScreenLine
}

function Wait-GerberRepositoryCreateContinue {
    [OutputType([bool])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('Wait-GerberRepositoryCreateContinue', 'Invoke')

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

function Convert-GerberListToNumberedMenuItemList {
    [OutputType([object[]])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$ItemList,

        [Parameter(Mandatory)]
        [string]$DisplayProperty,

        [string]$ValueProperty
    )
    $null = $PSCmdlet.ShouldProcess('Convert-GerberListToNumberedMenuItemList', 'Invoke')

    $index = 0
    return @(
        foreach ($item in $ItemList) {
            $index++
            $resolvedValue = if ($PSBoundParameters.ContainsKey('ValueProperty')) { $item.$ValueProperty } else { $item.$DisplayProperty }
            [pscustomobject]@{
                Number      = $index
                Label       = $item.$DisplayProperty
                Value       = $resolvedValue
                PreviewText = ''
            }
        }
    )
}
