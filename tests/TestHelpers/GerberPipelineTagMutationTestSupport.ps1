function Get-GerberPipelineTagMutationTestContext {
    [CmdletBinding()]
    param(
        [ValidateSet('update', 'delete')]
        [string]$Mode = 'update'
    )

    $operation = [pscustomobject]@{
        Mode         = $Mode
        CommandLabel = "/pipelines tags $Mode"
        TracePrefix  = "pipelines-tags-$Mode"
    }

    return [pscustomobject]@{
        Operation  = $operation
        Context    = [pscustomobject]@{ Configuration = 'cfg'; Pat = 'pat' }
        CurrentTag = 'old'
        NewTag     = 'new'
    }
}

function Assert-GerberPipelineTagMutationPlanReturnsNull {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$GetBuildListMock,

        [Parameter(Mandatory)]
        [string]$ExpectedMessage
    )

    $expectedRecoverableErrorMessage = $ExpectedMessage
    $testContext = Get-GerberPipelineTagMutationTestContext
    Mock Show-GerberPipelineReleaseLoadingScreen {}
    Mock Get-GerberAdoBuildListByTag $GetBuildListMock
    Mock Show-GerberPipelineReleaseRecoverableError {}

    $result = Get-GerberPipelineTagMutationPlanOrNull `
        -Context $testContext.Context `
        -Operation $testContext.Operation `
        -CurrentTag $testContext.CurrentTag `
        -NewTag $testContext.NewTag

    $result | Should -BeNullOrEmpty
    Should -Invoke Show-GerberPipelineReleaseRecoverableError -Times 1 -ParameterFilter { $Message -eq $expectedRecoverableErrorMessage }
}

function Get-GerberPipelineTagMutationApplyResult {
    [CmdletBinding()]
    param(
        [ValidateSet('update', 'delete')]
        [string]$Mode = 'update'
    )

    $plan = [pscustomobject]@{
        Mode         = $Mode
        CommandLabel = "/pipelines tags $Mode"
        TracePrefix  = "pipelines-tags-$Mode"
        CurrentTag   = 'old'
        NewTag       = $(if ($Mode -eq 'update') { 'new' } else { $null })
    }

    return [pscustomobject]@{
        Plan              = $plan
        ChangedBuildList  = @()
        FailedBuildList   = @()
        ExcludedBuildList = @()
    }
}

function Assert-GerberPipelineTagMutationContinueRouting {
    param(
        [Parameter(Mandatory)]
        [bool]$EscapeRequested,

        [Parameter(Mandatory)]
        [bool]$ExpectedReturnToParent
    )

    Mock Show-GerberTextBlock {}
    if ($EscapeRequested) {
        Mock Wait-GerberContinue { throw (Get-GerberMenuEscapeException) }
    } else {
        Mock Wait-GerberContinue {}
    }

    $result = Show-GerberPipelineTagMutationApplyResult -ApplyResult (Get-GerberPipelineTagMutationApplyResult)

    $result.ReturnToParent | Should -Be $ExpectedReturnToParent
}
