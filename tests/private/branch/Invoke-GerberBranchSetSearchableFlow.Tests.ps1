BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Invoke-GerberBranchSetSearchableFlow' {
    It 'returns without iterating when branch names input returns null' {
        Mock Show-GerberBranchSetSearchableHeader {}
        Mock Read-GerberSearchableBranchNamesInputOrNull { $null }
        Mock Invoke-GerberSearchableBranchIteration {}

        Invoke-GerberBranchSetSearchableFlow

        Should -Invoke Invoke-GerberSearchableBranchIteration -Times 0
    }

    It 'returns when iteration returns false' {
        Mock Show-GerberBranchSetSearchableHeader {}
        Mock Read-GerberSearchableBranchNamesInputOrNull { 'main' }
        Mock Invoke-GerberSearchableBranchIteration { $false }

        Invoke-GerberBranchSetSearchableFlow

        Should -Invoke Invoke-GerberSearchableBranchIteration -Times 1
    }

    It 'loops back to header and branch prompt when iteration returns true then exits on null input' {
        Mock Show-GerberBranchSetSearchableHeader {}
        $script:iterCallCount = 0
        Mock Read-GerberSearchableBranchNamesInputOrNull {
            $script:iterCallCount++
            if ($script:iterCallCount -eq 1) { return 'main' }
            return $null
        }
        Mock Invoke-GerberSearchableBranchIteration { $true }

        Invoke-GerberBranchSetSearchableFlow

        Should -Invoke Show-GerberBranchSetSearchableHeader -Times 2
        Should -Invoke Invoke-GerberSearchableBranchIteration -Times 1
    }
}

Describe 'Read-GerberSearchableBranchNamesInputOrNull' {
    It 'returns the typed value when no exception is thrown' {
        Mock Read-GerberCommand { 'main, dev' }

        $result = Read-GerberSearchableBranchNamesInputOrNull

        $result | Should -Be 'main, dev'
    }

    It 'returns null when Escape is pressed' {
        Mock Read-GerberCommand { throw (Get-GerberMenuEscapeException) }

        $result = Read-GerberSearchableBranchNamesInputOrNull

        $result | Should -BeNull
    }

    It 'rethrows non-escape exceptions' {
        Mock Read-GerberCommand { throw [System.InvalidOperationException]::new('unexpected') }

        { Read-GerberSearchableBranchNamesInputOrNull } | Should -Throw -ExceptionType ([System.InvalidOperationException])
    }
}

Describe 'Read-GerberSearchableBranchModeOrNull' {
    It 'returns the selected mode value' {
        Mock Read-GerberNumberedMenuPrompt { 'Replace' }

        $result = Read-GerberSearchableBranchModeOrNull

        $result | Should -Be 'Replace'
    }

    It 'returns null when Escape is pressed' {
        Mock Read-GerberNumberedMenuPrompt { throw (Get-GerberMenuEscapeException) }

        $result = Read-GerberSearchableBranchModeOrNull

        $result | Should -BeNull
    }

    It 'rethrows non-escape exceptions' {
        Mock Read-GerberNumberedMenuPrompt { throw [System.InvalidOperationException]::new('fail') }

        { Read-GerberSearchableBranchModeOrNull } | Should -Throw -ExceptionType ([System.InvalidOperationException])
    }
}

Describe 'Build-GerberSearchableBranchContext' {
    It 'normalizes comma-separated branch names using ConvertTo-GerberNormalizedBranchPath' {
        Mock Get-GerberAdoConfiguration {
            [pscustomobject]@{ CredentialIdentifier = 'gerber:ado:example:pat' }
        }
        Mock Resolve-GerberAdoPat { 'test-pat' }

        $context = Build-GerberSearchableBranchContext -BranchInput 'main, feature/x' -Mode 'Replace'

        $context.DesiredBranchList | Should -Contain 'refs/heads/main'
        $context.DesiredBranchList | Should -Contain 'refs/heads/feature/x'
    }

    It 'includes Mode, Configuration, and Pat in the returned context' {
        Mock Get-GerberAdoConfiguration {
            [pscustomobject]@{ CredentialIdentifier = 'gerber:ado:example:pat' }
        }
        Mock Resolve-GerberAdoPat { 'my-pat' }

        $context = Build-GerberSearchableBranchContext -BranchInput 'main' -Mode 'Merge'

        $context.Mode | Should -Be 'Merge'
        $context.Pat | Should -Be 'my-pat'
        $context.Configuration | Should -Not -BeNull
    }

    It 'trims whitespace around each branch name' {
        Mock Get-GerberAdoConfiguration {
            [pscustomobject]@{ CredentialIdentifier = 'gerber:ado:example:pat' }
        }
        Mock Resolve-GerberAdoPat { 'p' }

        $context = Build-GerberSearchableBranchContext -BranchInput '  main  ,  dev  ' -Mode 'Replace'

        $context.DesiredBranchList | Should -Contain 'refs/heads/main'
        $context.DesiredBranchList | Should -Contain 'refs/heads/dev'
    }
}

Describe 'Invoke-GerberSearchableBranchIteration' {
    It 'returns true without advancing when mode prompt returns null' {
        Mock Read-GerberSearchableBranchModeOrNull { $null }
        Mock Build-GerberSearchableBranchContext {}
        Mock Get-GerberAdoSearchableBranchPolicyReport {}

        $result = Invoke-GerberSearchableBranchIteration -BranchInput 'main'

        $result | Should -BeTrue
        Should -Invoke Build-GerberSearchableBranchContext -Times 0
    }

    It 'shows no-op result and returns Wait result when change count is zero' {
        Mock Read-GerberSearchableBranchModeOrNull { 'Replace' }
        Mock Build-GerberSearchableBranchContext {
            [pscustomobject]@{ Configuration = $null; Pat = 'p'; DesiredBranchList = @(); Mode = 'Replace' }
        }
        Mock Get-GerberAdoSearchableBranchPolicyReport {
            [pscustomobject]@{ CreateList = @(); UpdateList = @(); AlreadyAlignedList = @([pscustomobject]@{ RepoName = 'A' }) }
        }
        Mock Show-GerberSearchableBranchNoOpResult {}
        Mock Wait-GerberSearchableBranchContinue { $true }

        $result = Invoke-GerberSearchableBranchIteration -BranchInput 'main'

        $result | Should -BeTrue
        Should -Invoke Show-GerberSearchableBranchNoOpResult -Times 1
        Should -Invoke Wait-GerberSearchableBranchContinue -Times 1
    }

    It 'returns true when confirmation is cancelled' {
        Mock Read-GerberSearchableBranchModeOrNull { 'Replace' }
        Mock Build-GerberSearchableBranchContext {
            [pscustomobject]@{ Configuration = $null; Pat = 'p'; DesiredBranchList = @('refs/heads/main'); Mode = 'Replace' }
        }
        Mock Get-GerberAdoSearchableBranchPolicyReport {
            [pscustomobject]@{
                CreateList         = @([pscustomobject]@{ RepoId = 'r1'; RepoName = 'Alpha'; PolicyId = $null; NewScope = @() })
                UpdateList         = @()
                AlreadyAlignedList = @()
            }
        }
        Mock Confirm-GerberSearchableBranchApply { $false }
        Mock Invoke-GerberSearchableBranchApplyWithProgress {}

        $result = Invoke-GerberSearchableBranchIteration -BranchInput 'main'

        $result | Should -BeTrue
        Should -Invoke Invoke-GerberSearchableBranchApplyWithProgress -Times 0
    }

    It 'applies changes and shows results when confirmed' {
        Mock Read-GerberSearchableBranchModeOrNull { 'Replace' }
        Mock Build-GerberSearchableBranchContext {
            [pscustomobject]@{ Configuration = $null; Pat = 'p'; DesiredBranchList = @('refs/heads/main'); Mode = 'Replace' }
        }
        Mock Get-GerberAdoSearchableBranchPolicyReport {
            [pscustomobject]@{
                CreateList         = @([pscustomobject]@{ RepoId = 'r1'; RepoName = 'Alpha'; PolicyId = $null; NewScope = @() })
                UpdateList         = @()
                AlreadyAlignedList = @()
            }
        }
        Mock Confirm-GerberSearchableBranchApply { $true }
        Mock Show-GerberSearchableBranchApplyScreen {}
        Mock Invoke-GerberSearchableBranchApplyWithProgress {
            [pscustomobject]@{ Results = @(); UnchangedCount = 0 }
        }
        Mock Show-GerberSearchableBranchApplyResult {}
        Mock Wait-GerberSearchableBranchContinue { $false }

        $result = Invoke-GerberSearchableBranchIteration -BranchInput 'main'

        $result | Should -BeFalse
        Should -Invoke Show-GerberSearchableBranchApplyScreen -Times 1
        Should -Invoke Invoke-GerberSearchableBranchApplyWithProgress -Times 1
        Should -Invoke Show-GerberSearchableBranchApplyResult -Times 1
    }
}

Describe 'Show-GerberSearchableBranchPreview' {
    It 'shows Create, Update and Already aligned groups via the group helper' {
        Mock Clear-Host {}
        Mock Write-GerberScreenLine {}
        Mock Write-GerberSearchableBranchPreviewGroup {}

        Show-GerberSearchableBranchPreview -Report ([pscustomobject]@{
            CreateList         = @([pscustomobject]@{ RepoName = 'Alpha' })
            UpdateList         = @([pscustomobject]@{ RepoName = 'Beta' })
            AlreadyAlignedList = @([pscustomobject]@{ RepoName = 'Gamma' })
        })

        Should -Invoke Write-GerberSearchableBranchPreviewGroup -Times 3
        Should -Invoke Write-GerberSearchableBranchPreviewGroup -Times 1 -ParameterFilter { $Label -like 'Already aligned*' }
    }

    It 'shows the header line' {
        Mock Clear-Host {}
        Mock Write-GerberScreenLine {}
        Mock Write-GerberSearchableBranchPreviewGroup {}

        Show-GerberSearchableBranchPreview -Report ([pscustomobject]@{
            CreateList = @(); UpdateList = @(); AlreadyAlignedList = @()
        })

        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq '/branch set-searchable' }
    }
}

Describe 'Write-GerberSearchableBranchResultSummary' {
    It 'shows correct counts in the summary line' {
        Mock Write-GerberScreenLine {}

        Write-GerberSearchableBranchResultSummary `
            -Created @([pscustomobject]@{ RepoName = 'A' }) `
            -Updated @([pscustomobject]@{ RepoName = 'B'; RepoName2 = 'C' }) `
            -Unchanged 3 `
            -Failed @()

        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -like 'Created 1*Updated 1*Unchanged 3*Failed 0*' }
    }

    It 'shows [+] prefix for created and updated repos' {
        Mock Write-GerberScreenLine {}

        Write-GerberSearchableBranchResultSummary `
            -Created @([pscustomobject]@{ RepoName = 'Created1' }) `
            -Updated @([pscustomobject]@{ RepoName = 'Updated1' }) `
            -Unchanged 0 `
            -Failed @()

        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq '  [+] Created1' }
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq '  [+] Updated1' }
    }

    It 'shows [!] prefix for failed repos' {
        Mock Write-GerberScreenLine {}

        Write-GerberSearchableBranchResultSummary `
            -Created @() `
            -Updated @() `
            -Unchanged 0 `
            -Failed @([pscustomobject]@{ RepoName = 'Broken' })

        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq '  [!] Broken' }
    }
}

Describe 'Confirm-GerberSearchableBranchApply' {
    BeforeEach {
        Mock Show-GerberSearchableBranchPreview {}
    }

    It 'returns true when the confirmation action is selected' {
        Mock Read-GerberConfirmationPrompt { $true }

        $result = Confirm-GerberSearchableBranchApply -Report ([pscustomobject]@{ CreateList = @(); UpdateList = @(); AlreadyAlignedList = @() })

        $result | Should -BeTrue
    }

    It 'returns false when the cancel option is selected' {
        Mock Read-GerberConfirmationPrompt { $false }

        $result = Confirm-GerberSearchableBranchApply -Report ([pscustomobject]@{ CreateList = @(); UpdateList = @(); AlreadyAlignedList = @() })

        $result | Should -BeFalse
    }

    It 'returns false when Escape is pressed' {
        Mock Read-GerberConfirmationPrompt { throw (Get-GerberMenuEscapeException) }

        $result = Confirm-GerberSearchableBranchApply -Report ([pscustomobject]@{ CreateList = @(); UpdateList = @(); AlreadyAlignedList = @() })

        $result | Should -BeFalse
    }

    It 'rethrows non-escape exceptions' {
        Mock Read-GerberConfirmationPrompt { throw [System.InvalidOperationException]::new('fail') }

        { Confirm-GerberSearchableBranchApply -Report ([pscustomobject]@{ CreateList = @(); UpdateList = @(); AlreadyAlignedList = @() }) } | Should -Throw -ExceptionType ([System.InvalidOperationException])
    }

    It 'draws the preview before showing the confirm prompt' {
        Mock Read-GerberConfirmationPrompt { $true }
        $report = [pscustomobject]@{ CreateList = @([pscustomobject]@{ RepoName = 'X' }); UpdateList = @(); AlreadyAlignedList = @() }

        Confirm-GerberSearchableBranchApply -Report $report

        Should -Invoke Show-GerberSearchableBranchPreview -Times 1 -ParameterFilter { $Report.CreateList.Count -eq 1 }
    }
}

Describe 'Show-GerberBranchSetSearchableHeader' {
    It 'clears the host and writes the command title' {
        Mock Start-GerberScreen {}
        Mock Write-GerberScreenLine {}

        Show-GerberBranchSetSearchableHeader

        Should -Invoke Start-GerberScreen -Times 1 -ParameterFilter { $Name -eq '/branch set-searchable' }
        Should -Invoke Write-GerberScreenLine -Times 2
    }
}

Describe 'Show-GerberSearchableBranchApplyScreen' {
    It 'clears the host and writes the command title and blank line' {
        Mock Start-GerberScreen {}
        Mock Write-GerberScreenLine {}

        Show-GerberSearchableBranchApplyScreen

        Should -Invoke Start-GerberScreen -Times 1 -ParameterFilter { $Name -eq '/branch set-searchable' }
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq '/branch set-searchable' }
        Should -Invoke Write-GerberScreenLine -Times 2
    }
}

Describe 'Show-GerberSearchableBranchNoOpResult' {
    It 'clears the host and writes already aligned message with count' {
        $report = [pscustomobject]@{ AlreadyAlignedList = @(1, 2, 3) }
        Mock Start-GerberScreen {}
        Mock Write-GerberScreenLine {}

        Show-GerberSearchableBranchNoOpResult -Report $report

        Should -Invoke Start-GerberScreen -Times 1 -ParameterFilter { $Name -eq '/branch set-searchable' }
        Should -Invoke Write-GerberScreenLine -Times 3
    }
}

Describe 'Write-GerberSearchableBranchPreviewGroup' {
    It 'writes label and items when Items is non-empty' {
        $items = @(
            [pscustomobject]@{ RepoName = 'repo-a' }
            [pscustomobject]@{ RepoName = 'repo-b' }
        )
        Mock Write-GerberScreenLine {}

        Write-GerberSearchableBranchPreviewGroup -Label 'To create (2)' -Items $items

        Should -Invoke Write-GerberScreenLine -Times 4
    }

    It 'writes nothing when Items is empty' {
        Mock Write-GerberScreenLine {}

        Write-GerberSearchableBranchPreviewGroup -Label 'To update (0)' -Items @()

        Should -Invoke Write-GerberScreenLine -Times 0
    }

    It 'shows all items without truncation when exactly 8 are provided' {
        $items = 1..8 | ForEach-Object { [pscustomobject]@{ RepoName = "repo-$_" } }
        Mock Write-GerberScreenLine {}

        Write-GerberSearchableBranchPreviewGroup -Label 'To create (8)' -Items $items

        # label + 8 items + blank = 10 calls; no "... and N more" line
        Should -Invoke Write-GerberScreenLine -Times 10
        Should -Invoke Write-GerberScreenLine -Times 0 -ParameterFilter { $Text -like '  ... and*' }
    }

    It 'truncates at 8 and shows and-N-more line when Items count exceeds 8' {
        $items = 1..10 | ForEach-Object { [pscustomobject]@{ RepoName = "repo-$_" } }
        Mock Write-GerberScreenLine {}

        Write-GerberSearchableBranchPreviewGroup -Label 'To create (10)' -Items $items

        # label + 8 items + "... and 2 more" + blank = 11 calls
        Should -Invoke Write-GerberScreenLine -Times 11
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq '  ... and 2 more' }
    }
}

Describe 'Invoke-GerberSearchableBranchApplyWithProgress' {
    It 'calls Set-GerberAdoSearchableBranchPolicy for each work item and returns results' {
        $context = [pscustomobject]@{ Pat = 'pat'; Configuration = [pscustomobject]@{} }
        $item1 = [pscustomobject]@{ RepoName = 'repo1'; PolicyId = $null; NewScope = @() }
        $item2 = [pscustomobject]@{ RepoName = 'repo2'; PolicyId = '5'; NewScope = @() }
        $report = [pscustomobject]@{
            CreateList          = @($item1)
            UpdateList          = @($item2)
            AlreadyAlignedList  = @('x', 'y')
        }
        Mock Write-GerberProgressBar {}
        Mock Set-GerberAdoSearchableBranchPolicy {
            [pscustomobject]@{ Success = $true; IsCreate = $PolicyItem.PolicyId -eq $null }
        }

        $result = Invoke-GerberSearchableBranchApplyWithProgress -Context $context -Report $report

        $result.Results.Count | Should -Be 2
        $result.UnchangedCount | Should -Be 2
        Should -Invoke Set-GerberAdoSearchableBranchPolicy -Times 2
        Should -Invoke Write-GerberProgressBar -Times 2
    }
}

Describe 'Show-GerberSearchableBranchApplyResult' {
    It 'clears host and calls Write-GerberSearchableBranchResultSummary with correct counts' {
        $results = [pscustomobject]@{
            Results = @(
                [pscustomobject]@{ Success = $true; IsCreate = $true }
                [pscustomobject]@{ Success = $true; IsCreate = $false }
                [pscustomobject]@{ Success = $false; IsCreate = $false }
            )
            UnchangedCount = 3
        }
        Mock Start-GerberScreen {}
        Mock Write-GerberScreenLine {}
        Mock Write-GerberSearchableBranchResultSummary {}

        Show-GerberSearchableBranchApplyResult -Results $results

        Should -Invoke Start-GerberScreen -Times 1 -ParameterFilter { $Name -eq '/branch set-searchable' }
        Should -Invoke Write-GerberSearchableBranchResultSummary -Times 1 -ParameterFilter {
            $Created.Count -eq 1 -and $Updated.Count -eq 1 -and
            $Failed.Count -eq 1 -and $Unchanged -eq 3
        }
    }
}

Describe 'Wait-GerberSearchableBranchContinue' {
    It 'returns true when Enter is pressed' {
        Mock Wait-GerberContinue {}

        $result = Wait-GerberSearchableBranchContinue

        $result | Should -BeTrue
    }

    It 'returns false when Escape is pressed' {
        Mock Wait-GerberContinue { throw (Get-GerberMenuEscapeException) }

        $result = Wait-GerberSearchableBranchContinue

        $result | Should -BeFalse
    }

    It 'rethrows non-escape exceptions from Wait-GerberContinue' {
        Mock Wait-GerberContinue { throw [System.InvalidOperationException]::new('fail') }

        { Wait-GerberSearchableBranchContinue } | Should -Throw -ExceptionType ([System.InvalidOperationException])
    }
}
