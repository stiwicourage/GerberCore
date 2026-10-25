BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Invoke-GerberBranchSetDefaultFlow' {
    It 'returns without iterating when branch name input returns null' {
        Mock Show-GerberBranchSetDefaultHeader {}
        Mock Read-GerberSetDefaultBranchNameOrNull { $null }
        Mock Invoke-GerberSetDefaultIteration {}

        Invoke-GerberBranchSetDefaultFlow

        Should -Invoke Invoke-GerberSetDefaultIteration -Times 0
    }

    It 'returns when iteration returns false' {
        Mock Show-GerberBranchSetDefaultHeader {}
        Mock Read-GerberSetDefaultBranchNameOrNull { 'main' }
        Mock Invoke-GerberSetDefaultIteration { $false }

        Invoke-GerberBranchSetDefaultFlow

        Should -Invoke Invoke-GerberSetDefaultIteration -Times 1
    }

    It 'loops back to header and branch prompt when iteration returns true then exits on null input' {
        Mock Show-GerberBranchSetDefaultHeader {}
        $script:defaultIterCallCount = 0
        Mock Read-GerberSetDefaultBranchNameOrNull {
            $script:defaultIterCallCount++
            if ($script:defaultIterCallCount -eq 1) { return 'main' }
            return $null
        }
        Mock Invoke-GerberSetDefaultIteration { $true }

        Invoke-GerberBranchSetDefaultFlow

        Should -Invoke Show-GerberBranchSetDefaultHeader -Times 2
        Should -Invoke Invoke-GerberSetDefaultIteration -Times 1
    }
}

Describe 'Read-GerberSetDefaultBranchNameOrNull' {
    It 'returns the typed value when no exception is thrown' {
        Mock Read-GerberCommand { 'develop' }

        $result = Read-GerberSetDefaultBranchNameOrNull

        $result | Should -Be 'develop'
    }

    It 'returns null when Escape is pressed' {
        Mock Read-GerberCommand { throw (Get-GerberMenuEscapeException) }

        $result = Read-GerberSetDefaultBranchNameOrNull

        $result | Should -BeNull
    }

    It 'rethrows non-escape exceptions' {
        Mock Read-GerberCommand { throw [System.InvalidOperationException]::new('unexpected') }

        { Read-GerberSetDefaultBranchNameOrNull } | Should -Throw -ExceptionType ([System.InvalidOperationException])
    }
}

Describe 'Build-GerberSetDefaultContext' {
    It 'normalizes develop to refs/heads/develop and sets TargetBranch' {
        Mock Get-GerberAdoConfiguration { [pscustomobject]@{ CredentialIdentifier = 'gerber:ado:example:pat' } }
        Mock Resolve-GerberAdoPat { 'test-pat' }

        $context = Build-GerberSetDefaultContext -BranchInput 'develop'

        $context.TargetBranch | Should -Be 'refs/heads/develop'
    }

    It 'passes through already-normalized refs/heads/ paths unchanged' {
        Mock Get-GerberAdoConfiguration { [pscustomobject]@{ CredentialIdentifier = 'gerber:ado:example:pat' } }
        Mock Resolve-GerberAdoPat { 'p' }

        $context = Build-GerberSetDefaultContext -BranchInput 'refs/heads/main'

        $context.TargetBranch | Should -Be 'refs/heads/main'
    }

    It 'includes Configuration and Pat in the returned context' {
        Mock Get-GerberAdoConfiguration { [pscustomobject]@{ CredentialIdentifier = 'gerber:ado:example:pat' } }
        Mock Resolve-GerberAdoPat { 'my-pat' }

        $context = Build-GerberSetDefaultContext -BranchInput 'main'

        $context.Pat | Should -Be 'my-pat'
        $context.Configuration | Should -Not -BeNull
    }
}

Describe 'Show-GerberSetDefaultNoOpResult' {
    BeforeEach {
        Mock Clear-Host {}
        Mock Write-GerberScreenLine {}
    }

    It 'writes all-on-target message when NotFoundList is empty' {
        $report = [pscustomobject]@{
            AlreadyAlignedList = @(1, 2, 3)
            NotFoundList       = @()
        }
        Show-GerberSetDefaultNoOpResult -Report $report

        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -like 'All 3 repositories*' }
    }

    It 'calls Write-GerberScreenLine 3 times when all repos are on target' {
        $report = [pscustomobject]@{ AlreadyAlignedList = @(1, 2); NotFoundList = @() }
        Show-GerberSetDefaultNoOpResult -Report $report

        Should -Invoke Write-GerberScreenLine -Times 3
    }

    It 'writes branch-not-found message when NotFoundList has items' {
        $report = [pscustomobject]@{
            AlreadyAlignedList = @(1, 2)
            NotFoundList       = @([pscustomobject]@{ RepoName = 'X' })
        }
        Show-GerberSetDefaultNoOpResult -Report $report

        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -like '*branch not found (skipped)*' }
    }

    It 'calls Write-GerberScreenLine 3 times when some repos are not found' {
        $report = [pscustomobject]@{
            AlreadyAlignedList = @(1)
            NotFoundList       = @([pscustomobject]@{ RepoName = 'X' })
        }
        Show-GerberSetDefaultNoOpResult -Report $report

        Should -Invoke Write-GerberScreenLine -Times 3
    }
}

Describe 'Show-GerberSetDefaultPreview' {
    It 'calls Write-GerberSearchableBranchPreviewGroup 3 times with correct labels' {
        Mock Clear-Host {}
        Mock Write-GerberScreenLine {}
        Mock Write-GerberSearchableBranchPreviewGroup {}

        Show-GerberSetDefaultPreview -Report ([pscustomobject]@{
            ToUpdateList       = @([pscustomobject]@{ RepoName = 'A' })
            AlreadyAlignedList = @([pscustomobject]@{ RepoName = 'B' })
            NotFoundList       = @([pscustomobject]@{ RepoName = 'C' })
        })

        Should -Invoke Write-GerberSearchableBranchPreviewGroup -Times 3
        Should -Invoke Write-GerberSearchableBranchPreviewGroup -Times 1 -ParameterFilter { $Label -like 'To update*' }
        Should -Invoke Write-GerberSearchableBranchPreviewGroup -Times 1 -ParameterFilter { $Label -like 'Already on target*' }
        Should -Invoke Write-GerberSearchableBranchPreviewGroup -Times 1 -ParameterFilter { $Label -like 'Branch not found*' }
    }

    It 'shows the /branch set-default header line' {
        Mock Clear-Host {}
        Mock Write-GerberScreenLine {}
        Mock Write-GerberSearchableBranchPreviewGroup {}

        Show-GerberSetDefaultPreview -Report ([pscustomobject]@{
            ToUpdateList = @(); AlreadyAlignedList = @(); NotFoundList = @()
        })

        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq '/branch set-default' }
    }
}

Describe 'Confirm-GerberSetDefaultApply' {
    BeforeEach {
        Mock Show-GerberSetDefaultPreview {}
    }

    It 'returns true when the confirmation action is selected' {
        Mock Read-GerberConfirmationPrompt { $true }

        $result = Confirm-GerberSetDefaultApply -Report ([pscustomobject]@{
            ToUpdateList = @(); AlreadyAlignedList = @(); NotFoundList = @()
        })

        $result | Should -BeTrue
    }

    It 'returns false when the cancel option is selected' {
        Mock Read-GerberConfirmationPrompt { $false }

        $result = Confirm-GerberSetDefaultApply -Report ([pscustomobject]@{
            ToUpdateList = @(); AlreadyAlignedList = @(); NotFoundList = @()
        })

        $result | Should -BeFalse
    }

    It 'returns false when Escape is pressed' {
        Mock Read-GerberConfirmationPrompt { throw (Get-GerberMenuEscapeException) }

        $result = Confirm-GerberSetDefaultApply -Report ([pscustomobject]@{
            ToUpdateList = @(); AlreadyAlignedList = @(); NotFoundList = @()
        })

        $result | Should -BeFalse
    }

    It 'rethrows non-escape exceptions' {
        Mock Read-GerberConfirmationPrompt { throw [System.InvalidOperationException]::new('fail') }

        { Confirm-GerberSetDefaultApply -Report ([pscustomobject]@{
            ToUpdateList = @(); AlreadyAlignedList = @(); NotFoundList = @()
        }) } | Should -Throw -ExceptionType ([System.InvalidOperationException])
    }

    It 'draws the preview before showing the confirm prompt' {
        Mock Read-GerberConfirmationPrompt { $true }
        $report = [pscustomobject]@{
            ToUpdateList       = @([pscustomobject]@{ RepoName = 'X' })
            AlreadyAlignedList = @()
            NotFoundList       = @()
        }

        Confirm-GerberSetDefaultApply -Report $report

        Should -Invoke Show-GerberSetDefaultPreview -Times 1 -ParameterFilter { $Report.ToUpdateList.Count -eq 1 }
    }
}

Describe 'Invoke-GerberSetDefaultApplyWithProgress' {
    It 'calls Set-GerberAdoRepositoryDefaultBranch for each ToUpdateList item and returns counts' {
        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{ CredentialIdentifier = 'gerber:ado:example:pat' }
            Pat           = 'p'
            TargetBranch  = 'refs/heads/main'
        }
        $item1 = [pscustomobject]@{ RepoId = 'r1'; RepoName = 'Alpha'; Classification = 'ToUpdate' }
        $item2 = [pscustomobject]@{ RepoId = 'r2'; RepoName = 'Beta';  Classification = 'ToUpdate' }
        $report = [pscustomobject]@{
            ToUpdateList       = @($item1, $item2)
            AlreadyAlignedList = @([pscustomobject]@{ RepoName = 'C' }, [pscustomobject]@{ RepoName = 'D' })
            NotFoundList       = @([pscustomobject]@{ RepoName = 'E' })
        }
        Mock Write-GerberProgressBar {}
        Mock Set-GerberAdoRepositoryDefaultBranch {
            [pscustomobject]@{ RepoName = $RepoItem.RepoName; Success = $true }
        }

        $result = Invoke-GerberSetDefaultApplyWithProgress -Context $context -Report $report

        $result.Results.Count | Should -Be 2
        $result.UnchangedCount | Should -Be 2
        $result.NotFoundCount | Should -Be 1
        Should -Invoke Set-GerberAdoRepositoryDefaultBranch -Times 2
        Should -Invoke Write-GerberProgressBar -Times 2
    }

    It 'returns empty results and zero counts when ToUpdateList is empty' {
        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{ CredentialIdentifier = 'gerber:ado:example:pat' }
            Pat           = 'p'
            TargetBranch  = 'refs/heads/main'
        }
        $report = [pscustomobject]@{
            ToUpdateList       = @()
            AlreadyAlignedList = @()
            NotFoundList       = @()
        }
        Mock Write-GerberProgressBar {}

        $result = Invoke-GerberSetDefaultApplyWithProgress -Context $context -Report $report

        $result.Results.Count | Should -Be 0
    }
}

Describe 'Write-GerberSetDefaultResultSummary' {
    It 'writes the summary line with correct counts' {
        Mock Write-GerberScreenLine {}

        Write-GerberSetDefaultResultSummary `
            -Updated @([pscustomobject]@{ RepoName = 'A' }, [pscustomobject]@{ RepoName = 'B' }) `
            -Unchanged 3 `
            -NotFound 1 `
            -Failed @()

        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter {
            $Text -like 'Updated 2*Already on target 3*Not found (skipped) 1*Failed 0*'
        }
    }

    It 'shows [+] prefix for updated repos' {
        Mock Write-GerberScreenLine {}

        Write-GerberSetDefaultResultSummary `
            -Updated @([pscustomobject]@{ RepoName = 'Repo1' }) `
            -Unchanged 0 `
            -NotFound 0 `
            -Failed @()

        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq '  [+] Repo1' }
    }

    It 'shows [!] prefix for failed repos' {
        Mock Write-GerberScreenLine {}

        Write-GerberSetDefaultResultSummary `
            -Updated @() `
            -Unchanged 0 `
            -NotFound 0 `
            -Failed @([pscustomobject]@{ RepoName = 'Broken' })

        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq '  [!] Broken' }
    }
}

Describe 'Wait-GerberSetDefaultContinue' {
    It 'returns true when Enter is pressed' {
        Mock Wait-GerberContinue {}

        $result = Wait-GerberSetDefaultContinue

        $result | Should -BeTrue
    }

    It 'returns false when Escape is pressed' {
        Mock Wait-GerberContinue { throw (Get-GerberMenuEscapeException) }

        $result = Wait-GerberSetDefaultContinue

        $result | Should -BeFalse
    }

    It 'rethrows non-escape exceptions from Wait-GerberContinue' {
        Mock Wait-GerberContinue { throw [System.InvalidOperationException]::new('fail') }

        { Wait-GerberSetDefaultContinue } | Should -Throw -ExceptionType ([System.InvalidOperationException])
    }
}

Describe 'Invoke-GerberSetDefaultIteration' {
    It 'shows no-op result and returns Wait result when ToUpdateList is empty' {
        Mock Build-GerberSetDefaultContext {
            [pscustomobject]@{ Configuration = $null; Pat = 'p'; TargetBranch = 'refs/heads/main' }
        }
        Mock Get-GerberAdoDefaultBranchReport {
            [pscustomobject]@{
                ToUpdateList       = @()
                AlreadyAlignedList = @([pscustomobject]@{ RepoName = 'A' })
                NotFoundList       = @()
            }
        }
        Mock Show-GerberSetDefaultNoOpResult {}
        Mock Wait-GerberSetDefaultContinue { $true }

        $result = Invoke-GerberSetDefaultIteration -BranchInput 'main'

        $result | Should -BeTrue
        Should -Invoke Show-GerberSetDefaultNoOpResult -Times 1
        Should -Invoke Wait-GerberSetDefaultContinue -Times 1
    }

    It 'returns true when confirmation is cancelled' {
        Mock Build-GerberSetDefaultContext {
            [pscustomobject]@{ Configuration = $null; Pat = 'p'; TargetBranch = 'refs/heads/main' }
        }
        Mock Get-GerberAdoDefaultBranchReport {
            [pscustomobject]@{
                ToUpdateList       = @([pscustomobject]@{ RepoId = 'r1'; RepoName = 'Alpha'; Classification = 'ToUpdate' })
                AlreadyAlignedList = @()
                NotFoundList       = @()
            }
        }
        Mock Confirm-GerberSetDefaultApply { $false }
        Mock Write-GerberPromptTrace {}
        Mock Invoke-GerberSetDefaultApplyWithProgress {}

        $result = Invoke-GerberSetDefaultIteration -BranchInput 'main'

        $result | Should -BeTrue
        Should -Invoke Invoke-GerberSetDefaultApplyWithProgress -Times 0
    }

    It 'applies changes and shows results when confirmed' {
        Mock Build-GerberSetDefaultContext {
            [pscustomobject]@{ Configuration = $null; Pat = 'p'; TargetBranch = 'refs/heads/main' }
        }
        Mock Get-GerberAdoDefaultBranchReport {
            [pscustomobject]@{
                ToUpdateList       = @([pscustomobject]@{ RepoId = 'r1'; RepoName = 'Alpha'; Classification = 'ToUpdate' })
                AlreadyAlignedList = @()
                NotFoundList       = @()
            }
        }
        Mock Confirm-GerberSetDefaultApply { $true }
        Mock Write-GerberPromptTrace {}
        Mock Show-GerberBranchSetDefaultApplyScreen {}
        Mock Invoke-GerberSetDefaultApplyWithProgress {
            [pscustomobject]@{ Results = @(); UnchangedCount = 0; NotFoundCount = 0 }
        }
        Mock Show-GerberSetDefaultApplyResult {}
        Mock Wait-GerberSetDefaultContinue { $false }

        $result = Invoke-GerberSetDefaultIteration -BranchInput 'main'

        $result | Should -BeFalse
        Should -Invoke Show-GerberBranchSetDefaultApplyScreen -Times 1
        Should -Invoke Invoke-GerberSetDefaultApplyWithProgress -Times 1
        Should -Invoke Show-GerberSetDefaultApplyResult -Times 1
    }
}

Describe '<Command>' -ForEach @(
    @{ Command = 'Show-GerberBranchSetDefaultHeader' }
    @{ Command = 'Show-GerberBranchSetDefaultApplyScreen' }
) {
    It 'clears the host and writes the command title and blank line' {
        Mock Start-GerberScreen {}
        Mock Write-GerberScreenLine {}

        & $Command

        Should -Invoke Start-GerberScreen -Times 1 -ParameterFilter { $Name -eq '/branch set-default' }
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq '/branch set-default' }
        Should -Invoke Write-GerberScreenLine -Times 2
    }
}

Describe 'Show-GerberSetDefaultApplyResult' {
    It 'clears host and calls Write-GerberSetDefaultResultSummary with correct counts' {
        $results = [pscustomobject]@{
            Results = @(
                [pscustomobject]@{ RepoName = 'Alpha'; Success = $true }
                [pscustomobject]@{ RepoName = 'Beta';  Success = $false }
            )
            UnchangedCount = 2
            NotFoundCount  = 1
        }
        Mock Start-GerberScreen {}
        Mock Write-GerberScreenLine {}
        Mock Write-GerberSetDefaultResultSummary {}

        Show-GerberSetDefaultApplyResult -Results $results

        Should -Invoke Start-GerberScreen -Times 1 -ParameterFilter { $Name -eq '/branch set-default' }
        Should -Invoke Write-GerberSetDefaultResultSummary -Times 1 -ParameterFilter {
            $Updated.Count -eq 1 -and $Failed.Count -eq 1 -and
            $Unchanged -eq 2 -and $NotFound -eq 1
        }
    }
}
