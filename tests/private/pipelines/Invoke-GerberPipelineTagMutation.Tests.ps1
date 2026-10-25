BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberPipelineTagMutationTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Invoke-GerberPipelineTagMutation' {
    It 'returns immediately when the current-tag prompt is cancelled' {
        $testContext = Get-GerberPipelineTagMutationTestContext
        Mock Get-GerberPipelineReleaseContext { [pscustomobject]@{} }
        Mock Read-GerberPipelineTagMutationCurrentTagOrNull { $null }
        Mock Invoke-GerberPipelineTagMutationCurrentTagFlow {}

        Invoke-GerberPipelineTagMutation -Operation $testContext.Operation

        Should -Invoke Invoke-GerberPipelineTagMutationCurrentTagFlow -Times 0
    }

    It 'repeats the action after a completed batch and stops when the next current-tag prompt is cancelled' {
        $testContext = Get-GerberPipelineTagMutationTestContext
        $script:currentTagCallCount = 0
        Mock Get-GerberPipelineReleaseContext { [pscustomobject]@{ Configuration = 'cfg'; Pat = 'pat' } }
        Mock Read-GerberPipelineTagMutationCurrentTagOrNull {
            $script:currentTagCallCount++
            if ($script:currentTagCallCount -eq 1) {
                return 'old'
            }

            return $null
        }
        Mock Invoke-GerberPipelineTagMutationCurrentTagFlow { [pscustomobject]@{ ReturnToParent = $false } }

        Invoke-GerberPipelineTagMutation -Operation $testContext.Operation

        Should -Invoke Invoke-GerberPipelineTagMutationCurrentTagFlow -Times 1
    }
}

Describe 'Invoke-GerberPipelineTagMutationCurrentTagFlow' {
    It 'returns to the current-tag prompt when the next step is cancelled' {
        $testContext = Get-GerberPipelineTagMutationTestContext
        Mock Get-GerberPipelineTagMutationPlanInputOrNull { $null }

        $result = Invoke-GerberPipelineTagMutationCurrentTagFlow `
            -Context ([pscustomobject]@{}) `
            -Operation $testContext.Operation `
            -CurrentTag 'old'

        $result.ReturnToParent | Should -BeFalse
    }

    It 'returns the apply-result routing after a successful apply' {
        $testContext = Get-GerberPipelineTagMutationTestContext
        Mock Get-GerberPipelineTagMutationPlanInputOrNull { [pscustomobject]@{ NewTag = 'new' } }
        Mock Get-GerberPipelineTagMutationPlanOrNull { [pscustomobject]@{ CommandLabel = '/pipelines tags update'; TracePrefix = 'pipelines-tags-update'; CurrentTag = 'old'; NewTag = 'new'; BuildList = @([pscustomobject]@{}) } }
        Mock Invoke-GerberPipelineTagMutationPlanFlow { [pscustomobject]@{ ReturnToParent = $true } }

        $result = Invoke-GerberPipelineTagMutationCurrentTagFlow `
            -Context ([pscustomobject]@{ Configuration = 'cfg'; Pat = 'pat' }) `
            -Operation $testContext.Operation `
            -CurrentTag 'old'

        $result.ReturnToParent | Should -BeTrue
    }

    It 'returns to the current-tag prompt when delete mode finds no matching tagged runs' {
        $testContext = Get-GerberPipelineTagMutationTestContext -Mode delete
        Mock Get-GerberPipelineTagMutationPlanInputOrNull { [pscustomobject]@{ NewTag = $null } }
        Mock Get-GerberPipelineTagMutationPlanOrNull { $null }

        $result = Invoke-GerberPipelineTagMutationCurrentTagFlow `
            -Context ([pscustomobject]@{ Configuration = 'cfg'; Pat = 'pat' }) `
            -Operation $testContext.Operation `
            -CurrentTag 'old'

        $result.ReturnToParent | Should -BeFalse
    }
}

Describe 'Get-GerberPipelineTagMutationPlanInputOrNull' {
    It 'skips the new-tag prompt for delete mode' {
        $testContext = Get-GerberPipelineTagMutationTestContext -Mode delete
        Mock Read-GerberPipelineTagMutationNewTagOrNull {}

        $result = Get-GerberPipelineTagMutationPlanInputOrNull -Operation $testContext.Operation -CurrentTag 'old'

        $result.NewTag | Should -BeNullOrEmpty
        Should -Invoke Read-GerberPipelineTagMutationNewTagOrNull -Times 0
    }

    It 'returns the prompted new tag for update mode' {
        $testContext = Get-GerberPipelineTagMutationTestContext
        Mock Read-GerberPipelineTagMutationNewTagOrNull { 'new' }

        $result = Get-GerberPipelineTagMutationPlanInputOrNull -Operation $testContext.Operation -CurrentTag 'old'

        $result.NewTag | Should -Be 'new'
    }
}

Describe 'Test-GerberPipelineTagMutationBackRequested' {
    It 'returns true only when the plan flow result explicitly requests back-navigation' {
        (Test-GerberPipelineTagMutationBackRequested -PlanFlowResult $null) | Should -BeFalse
        (Test-GerberPipelineTagMutationBackRequested -PlanFlowResult ([pscustomobject]@{ ReturnToParent = $true })) | Should -BeFalse
        (Test-GerberPipelineTagMutationBackRequested -PlanFlowResult ([pscustomobject]@{ BackRequested = $false })) | Should -BeFalse
        (Test-GerberPipelineTagMutationBackRequested -PlanFlowResult ([pscustomobject]@{ BackRequested = $true })) | Should -BeTrue
    }
}

Describe 'Invoke-GerberPipelineTagMutationPlanFlow' {
    It 'returns BackRequested when the selection prompt is cancelled' {
        Mock Read-GerberPipelineTagMutationSelectionOrNull { $null }

        $result = Invoke-GerberPipelineTagMutationPlanFlow `
            -Context ([pscustomobject]@{}) `
            -Plan ([pscustomobject]@{})

        $result.BackRequested | Should -BeTrue
    }

    It 'returns the apply-result routing after a confirmed apply' {
        Mock Read-GerberPipelineTagMutationSelectionOrNull { [pscustomobject]@{ SelectedBuildList = @(); ExcludedBuildList = @() } }
        Mock Confirm-GerberPipelineTagMutationApply { $true }
        Mock Invoke-GerberPipelineTagMutationApply { Get-GerberPipelineTagMutationApplyResult }
        Mock Show-GerberPipelineTagMutationApplyResult { [pscustomobject]@{ ReturnToParent = $true } }

        $result = Invoke-GerberPipelineTagMutationPlanFlow `
            -Context ([pscustomobject]@{ Configuration = 'cfg'; Pat = 'pat' }) `
            -Plan ([pscustomobject]@{ CommandLabel = '/pipelines tags update'; TracePrefix = 'pipelines-tags-update'; CurrentTag = 'old'; NewTag = 'new' })

        $result.ReturnToParent | Should -BeTrue
    }
}

Describe 'Read-GerberPipelineTagMutationCurrentTagOrNull' {
    It 'returns null when Escape is pressed' {
        $testContext = Get-GerberPipelineTagMutationTestContext
        Mock Read-GerberCommand { throw (Get-GerberMenuEscapeException) }

        $result = Read-GerberPipelineTagMutationCurrentTagOrNull -Operation $testContext.Operation

        $result | Should -BeNullOrEmpty
    }

    It 'retries after an empty current tag' {
        $testContext = Get-GerberPipelineTagMutationTestContext
        $script:currentTagPromptCount = 0
        Mock Read-GerberCommand {
            $script:currentTagPromptCount++
            if ($script:currentTagPromptCount -eq 1) {
                return ''
            }

            return 'release-tag'
        }
        Mock Show-GerberPipelineReleaseRecoverableError {}

        $result = Read-GerberPipelineTagMutationCurrentTagOrNull -Operation $testContext.Operation

        $result | Should -Be 'release-tag'
        Should -Invoke Show-GerberPipelineReleaseRecoverableError -Times 1
    }
}

Describe 'Get-GerberPipelineTagMutationCurrentTagHintText' {
    It 'uses mode-specific prompt guidance' {
        (Get-GerberPipelineTagMutationCurrentTagHintText -Operation ([pscustomobject]@{ Mode = 'update' })) | Should -Be 'Enter the tag that Gerber should replace on existing pipeline runs.'
        (Get-GerberPipelineTagMutationCurrentTagHintText -Operation ([pscustomobject]@{ Mode = 'delete' })) | Should -Be 'Enter the tag that Gerber should delete from existing pipeline runs.'
    }
}

Describe 'Read-GerberPipelineTagMutationNewTagOrNull' {
    It 'returns null when Escape is pressed' {
        $testContext = Get-GerberPipelineTagMutationTestContext
        Mock Read-GerberCommand { throw (Get-GerberMenuEscapeException) }

        $result = Read-GerberPipelineTagMutationNewTagOrNull -Operation $testContext.Operation -CurrentTag 'old'

        $result | Should -BeNullOrEmpty
    }

    It 'retries when the new tag is empty or unchanged' {
        $testContext = Get-GerberPipelineTagMutationTestContext
        $script:newTagPromptCount = 0
        Mock Read-GerberCommand {
            $script:newTagPromptCount++
            switch ($script:newTagPromptCount) {
                1 { return '' }
                2 { return 'old' }
                default { return 'new' }
            }
        }
        Mock Show-GerberPipelineReleaseRecoverableError {}

        $result = Read-GerberPipelineTagMutationNewTagOrNull -Operation $testContext.Operation -CurrentTag 'old'

        $result | Should -Be 'new'
        Should -Invoke Show-GerberPipelineReleaseRecoverableError -Times 2
    }
}

Describe 'Get-GerberPipelineTagMutationPlanOrNull' {
    It 'returns null and shows a recoverable error when the tag lookup fails' {
        Assert-GerberPipelineTagMutationPlanReturnsNull `
            -GetBuildListMock { throw [System.ArgumentException]::new('Lookup failed') } `
            -ExpectedMessage 'Lookup failed'
    }

    It 'sorts matching runs by pipeline name and newest queue time first' {
        $testContext = Get-GerberPipelineTagMutationTestContext
        Mock Show-GerberPipelineReleaseLoadingScreen {}
        Mock Get-GerberAdoBuildListByTag {
            @(
                [pscustomobject]@{ DefinitionName = 'Pipeline B'; QueueTime = [datetime]'2026-06-19T08:00:00Z'; BuildId = 10 },
                [pscustomobject]@{ DefinitionName = 'Pipeline A'; QueueTime = [datetime]'2026-06-19T09:00:00Z'; BuildId = 12 },
                [pscustomobject]@{ DefinitionName = 'Pipeline A'; QueueTime = [datetime]'2026-06-19T07:00:00Z'; BuildId = 11 }
            )
        }

        $result = Get-GerberPipelineTagMutationPlanOrNull `
            -Context $testContext.Context `
            -Operation $testContext.Operation `
            -CurrentTag $testContext.CurrentTag `
            -NewTag $testContext.NewTag

        $result.BuildList.BuildId | Should -Be @(12, 11, 10)
    }

    It 'returns null when no tagged runs match the current tag' {
        Assert-GerberPipelineTagMutationPlanReturnsNull `
            -GetBuildListMock { @() } `
            -ExpectedMessage "Gerber could not find any pipeline runs tagged 'old'."
    }
}

Describe 'Read-GerberPipelineTagMutationSelectionOrNull' {
    It 'returns null when Escape is pressed in the checkbox chooser' {
        Mock Read-GerberCheckboxMenuPrompt { throw (Get-GerberMenuEscapeException) }

        $result = Read-GerberPipelineTagMutationSelectionOrNull -Plan ([pscustomobject]@{ CommandLabel = '/pipelines tags update'; BuildList = @() })

        $result | Should -BeNullOrEmpty
    }
}

Describe 'Get-GerberPipelineTagMutationCheckboxItemList' {
    It 'creates one checkbox item per tagged run with build details on one line' {
        $result = Get-GerberPipelineTagMutationCheckboxItemList `
            -Plan ([pscustomobject]@{
                BuildList = @(
                    [pscustomobject]@{
                        DefinitionName = 'Pipeline A'
                        BuildNumber    = '2026.01'
                        BuildId        = 1001
                        QueueTimeText  = '2026-06-19 09:00'
                        Status         = 'completed'
                        Result         = 'succeeded'
                    }
                )
            })

        $result[0].Label | Should -Be 'Pipeline A / 2026.01 | BuildId: 1001 | Queued: 2026-06-19 09:00 | Status: completed/succeeded'
        $result[0].Description | Should -Be ''
    }
}

Describe 'ConvertTo-GerberPipelineTagMutationSelection' {
    It 'separates selected and excluded builds from the checkbox result' {
        $selectedBuild = [pscustomobject]@{ BuildId = 1 }
        $excludedBuild = [pscustomobject]@{ BuildId = 2 }

        $result = ConvertTo-GerberPipelineTagMutationSelection `
            -CheckboxResult ([pscustomobject]@{
                SelectedItemList   = @([pscustomobject]@{ Build = $selectedBuild })
                DeselectedItemList = @([pscustomobject]@{ Build = $excludedBuild })
            })

        $result.SelectedBuildList.BuildId | Should -Be @(1)
        $result.ExcludedBuildList.BuildId | Should -Be @(2)
    }
}

Describe 'Invoke-GerberPipelineTagMutationApply' {
    It 'continues changing the remaining selected runs after one failure' {
        $successfulBuild = [pscustomobject]@{
            BuildId        = 1001
            DefinitionName = 'Pipeline A'
            BuildNumber    = '2026.01'
            RunUrl         = 'https://ado/build/1001'
        }
        $failingBuild = [pscustomobject]@{
            BuildId        = 1002
            DefinitionName = 'Pipeline B'
            BuildNumber    = '2026.02'
            RunUrl         = 'https://ado/build/1002'
        }
        Mock Invoke-GerberPipelineTagMutationBuild {
            if ($Build.BuildId -eq 1002) {
                throw [System.ArgumentException]::new('Update failed')
            }
        }

        $result = Invoke-GerberPipelineTagMutationApply `
            -ApplyRequest ([pscustomobject]@{
                Configuration = [pscustomobject]@{}
                Pat           = 'pat'
                Plan          = [pscustomobject]@{ Mode = 'update'; CurrentTag = 'old'; NewTag = 'new' }
                Selection     = [pscustomobject]@{
                    SelectedBuildList = @($successfulBuild, $failingBuild)
                    ExcludedBuildList = @()
                }
            })

        $result.ChangedBuildList.BuildId | Should -Be @(1001)
        $result.FailedBuildList.Build.BuildId | Should -Be @(1002)
        $result.FailedBuildList[0].ErrorDetail | Should -Be "Could not replace tag 'old' with 'new' on BuildId 1002. Update failed"
    }
}

Describe 'Invoke-GerberPipelineTagMutationBuild' {
    It 'applies the expected tag mutation behavior for <Mode> mode' -ForEach @(
        @{ Mode = 'update'; NewTag = 'new'; ExpectedAddCount = 1 }
        @{ Mode = 'delete'; NewTag = $null; ExpectedAddCount = 0 }
    ) {
        Mock Remove-GerberAdoBuildTag {}
        Mock Add-GerberAdoBuildTag {}

        Invoke-GerberPipelineTagMutationBuild `
            -Configuration ([pscustomobject]@{}) `
            -Pat 'pat' `
            -Build ([pscustomobject]@{ BuildId = 1001 }) `
            -Plan ([pscustomobject]@{ Mode = $Mode; CurrentTag = 'old'; NewTag = $NewTag })

        Should -Invoke Remove-GerberAdoBuildTag -Times 1 -Exactly
        Should -Invoke Add-GerberAdoBuildTag -Times $ExpectedAddCount -Exactly
    }
}

Describe 'Get-GerberPipelineTagMutationSelectionText' {
    It 'renders the expected tag summary lines for <Mode> mode' -ForEach @(
        @{ Mode = 'update'; NewTag = 'new'; ExpectedPattern = 'New tag: new'; NegatedPattern = $null }
        @{ Mode = 'delete'; NewTag = $null; ExpectedPattern = 'Current tag: old'; NegatedPattern = 'New tag:' }
    ) {
        $result = Get-GerberPipelineTagMutationSelectionText `
            -Plan ([pscustomobject]@{
                Mode       = $Mode
                CurrentTag = 'old'
                NewTag     = $NewTag
                BuildList  = @([pscustomobject]@{ DefinitionName = 'Pipeline A'; QueueTime = [datetime]'2026-06-19T08:00:00Z' })
            })

        $result | Should -Match 'Current tag: old'
        $result | Should -Match $ExpectedPattern
        if ($null -ne $NegatedPattern) {
            $result | Should -Not -Match $NegatedPattern
        }
    }
}

Describe 'Get-GerberPipelineTagMutationConfirmationText' {
    It 'includes both the selected and skipped runs' {
        $result = Get-GerberPipelineTagMutationConfirmationText `
            -Plan ([pscustomobject]@{ Mode = 'update'; CurrentTag = 'old'; NewTag = 'new' }) `
            -Selection ([pscustomobject]@{
                SelectedBuildList = @([pscustomobject]@{ DefinitionName = 'Pipeline A'; BuildNumber = '2026.01' })
                ExcludedBuildList = @([pscustomobject]@{ DefinitionName = 'Pipeline B'; BuildNumber = '2026.02' })
            })

        $result | Should -Match 'Apply to'
        $result | Should -Match 'Skip'
        $result | Should -Match 'Pipeline A / 2026.01'
        $result | Should -Match 'Pipeline B / 2026.02'
    }

    It 'uses delete wording in delete mode' {
        $result = Get-GerberPipelineTagMutationConfirmationText `
            -Plan ([pscustomobject]@{ Mode = 'delete'; CurrentTag = 'old'; NewTag = $null }) `
            -Selection ([pscustomobject]@{ SelectedBuildList = @(); ExcludedBuildList = @() })

        $result | Should -Match "Delete tag 'old'"
    }
}

Describe 'Confirm-GerberPipelineTagMutationApply' {
    It 'returns false when Escape is pressed at the confirmation prompt' {
        Mock Read-GerberConfirmationPrompt { throw (Get-GerberMenuEscapeException) }

        $result = Confirm-GerberPipelineTagMutationApply `
            -Plan ([pscustomobject]@{ Mode = 'update'; CommandLabel = '/pipelines tags update'; CurrentTag = 'old'; NewTag = 'new' }) `
            -Selection ([pscustomobject]@{ SelectedBuildList = @(); ExcludedBuildList = @() })

        $result | Should -BeFalse
    }
}

Describe 'Get-GerberPipelineTagMutationConfirmationIntro' {
    It 'returns mode-specific confirmation intros' {
        (Get-GerberPipelineTagMutationConfirmationIntro -Plan ([pscustomobject]@{ Mode = 'update'; CurrentTag = 'old'; NewTag = 'new' })) | Should -Be "Replace tag 'old' with 'new' on the selected pipeline runs."
        (Get-GerberPipelineTagMutationConfirmationIntro -Plan ([pscustomobject]@{ Mode = 'delete'; CurrentTag = 'old'; NewTag = $null })) | Should -Be "Delete tag 'old' from the selected pipeline runs."
    }
}

Describe 'Get-GerberPipelineTagMutationApplyPreviewText' {
    It 'summarizes the selected update batch' {
        $result = Get-GerberPipelineTagMutationApplyPreviewText `
            -Plan ([pscustomobject]@{ Mode = 'update'; CurrentTag = 'old'; NewTag = 'new' }) `
            -Selection ([pscustomobject]@{ SelectedBuildList = @(1, 2, 3) })

        $result | Should -Be "Update 3 selected pipeline run(s) from 'old' to 'new'."
    }

    It 'summarizes the selected delete batch' {
        $result = Get-GerberPipelineTagMutationApplyPreviewText `
            -Plan ([pscustomobject]@{ Mode = 'delete'; CurrentTag = 'old'; NewTag = $null }) `
            -Selection ([pscustomobject]@{ SelectedBuildList = @(1, 2, 3) })

        $result | Should -Be "Delete tag 'old' from 3 selected pipeline run(s)."
    }
}

Describe 'Get-GerberPipelineTagMutationApplyResultText' {
    It 'renders the expected result summary for <Mode> mode' -ForEach @(
        @{
            Mode                   = 'update'
            NewTag                 = 'new'
            ExpectedSummaryLabel   = 'Updated: 1'
            ExpectedSectionHeading = 'Updated now'
            ExpectedFailureHeading = 'Failed to update'
            NegatedPattern         = $null
        }
        @{
            Mode                   = 'delete'
            NewTag                 = $null
            ExpectedSummaryLabel   = 'Deleted: 1'
            ExpectedSectionHeading = 'Deleted now'
            ExpectedFailureHeading = 'Failed to delete'
            NegatedPattern         = 'New tag:'
        }
    ) {
        $result = Get-GerberPipelineTagMutationApplyResultText `
            -ApplyResult ([pscustomobject]@{
                Plan = [pscustomobject]@{ Mode = $Mode; CurrentTag = 'old'; NewTag = $NewTag }
                ChangedBuildList = @([pscustomobject]@{ DefinitionName = 'Pipeline A'; BuildNumber = '2026.01'; RunUrl = 'https://ado/build/1001' })
                FailedBuildList = @([pscustomobject]@{ Build = [pscustomobject]@{ DefinitionName = 'Pipeline B'; BuildNumber = '2026.02' }; ErrorDetail = 'Failed' })
                ExcludedBuildList = @([pscustomobject]@{ DefinitionName = 'Pipeline C'; BuildNumber = '2026.03' })
            })

        $result | Should -Match $ExpectedSummaryLabel
        $result | Should -Match 'Failed: 1'
        $result | Should -Match 'Skipped: 1'
        $result | Should -Match $ExpectedSectionHeading
        $result | Should -Match $ExpectedFailureHeading
        if ($null -ne $NegatedPattern) {
            $result | Should -Not -Match $NegatedPattern
        }
    }
}

Describe 'Get-GerberPipelineTagMutationChangedSummaryLabel' {
    It 'returns mode-specific result summary labels' {
        (Get-GerberPipelineTagMutationChangedSummaryLabel -Plan ([pscustomobject]@{ Mode = 'update' })) | Should -Be 'Updated'
        (Get-GerberPipelineTagMutationChangedSummaryLabel -Plan ([pscustomobject]@{ Mode = 'delete' })) | Should -Be 'Deleted'
    }
}

Describe 'Get-GerberPipelineTagMutationChangedSectionHeading' {
    It 'returns mode-specific result section headings' {
        (Get-GerberPipelineTagMutationChangedSectionHeading -Plan ([pscustomobject]@{ Mode = 'update' })) | Should -Be 'Updated now'
        (Get-GerberPipelineTagMutationChangedSectionHeading -Plan ([pscustomobject]@{ Mode = 'delete' })) | Should -Be 'Deleted now'
    }
}

Describe 'Pipeline tag mutation result sections' {
    It 'returns no lines for empty failure sections' {
        @(Get-GerberPipelineTagMutationBuildSectionLineList -Heading 'Changed now' -ItemList @() -ItemTextScript { param($item) $item }) | Should -Be @('Changed now')
        @(Get-GerberPipelineTagMutationFailureSectionLineList -ApplyResult (Get-GerberPipelineTagMutationApplyResult)) | Should -BeNullOrEmpty
    }

    It 'builds named sections from pipeline runs' {
        $result = Get-GerberPipelineTagMutationBuildSectionLineList `
            -Heading 'Updated now' `
            -ItemList @([pscustomobject]@{ DefinitionName = 'Pipeline A'; BuildNumber = '2026.01' }) `
            -ItemTextScript { param($build) "- $($build.DefinitionName) / $($build.BuildNumber)" }

        $result | Should -Be @('Updated now', '- Pipeline A / 2026.01')
    }
}

Describe 'ConvertTo-GerberPipelineTagMutationFailure' {
    It 'creates update wording for update failures' {
        $result = ConvertTo-GerberPipelineTagMutationFailure `
            -Build ([pscustomobject]@{ BuildId = 1002 }) `
            -Plan ([pscustomobject]@{ Mode = 'update'; CurrentTag = 'old'; NewTag = 'new' }) `
            -Message 'Update failed'

        $result.ErrorDetail | Should -Be "Could not replace tag 'old' with 'new' on BuildId 1002. Update failed"
    }

    It 'creates delete wording for delete failures' {
        $result = ConvertTo-GerberPipelineTagMutationFailure `
            -Build ([pscustomobject]@{ BuildId = 1002 }) `
            -Plan ([pscustomobject]@{ Mode = 'delete'; CurrentTag = 'old'; NewTag = $null }) `
            -Message 'Delete failed'

        $result.ErrorDetail | Should -Be "Could not delete tag 'old' from BuildId 1002. Delete failed"
    }
}

Describe 'Get-GerberPipelineTagMutationFailureMessage' {
    It 'returns mode-specific failure messages' {
        (Get-GerberPipelineTagMutationFailureMessage `
            -Build ([pscustomobject]@{ BuildId = 1002 }) `
            -Plan ([pscustomobject]@{ Mode = 'update'; CurrentTag = 'old'; NewTag = 'new' }) `
            -Message 'Update failed') | Should -Be "Could not replace tag 'old' with 'new' on BuildId 1002. Update failed"

        (Get-GerberPipelineTagMutationFailureMessage `
            -Build ([pscustomobject]@{ BuildId = 1002 }) `
            -Plan ([pscustomobject]@{ Mode = 'delete'; CurrentTag = 'old'; NewTag = $null }) `
            -Message 'Delete failed') | Should -Be "Could not delete tag 'old' from BuildId 1002. Delete failed"
    }
}

Describe 'Show-GerberPipelineTagMutationApplyResult' {
    It 'returns to the current action after Enter' {
        Assert-GerberPipelineTagMutationContinueRouting -EscapeRequested:$false -ExpectedReturnToParent:$false
    }

    It 'returns to the parent chooser after Escape on the continue prompt' {
        Assert-GerberPipelineTagMutationContinueRouting -EscapeRequested:$true -ExpectedReturnToParent:$true
    }
}
