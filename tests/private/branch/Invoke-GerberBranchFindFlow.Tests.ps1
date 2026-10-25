BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Invoke-GerberBranchFindFlow' {
    It 'shows header, searches, shows result, then exits when continue returns false' {
        Mock Show-GerberBranchFindHeader {}
        Mock Read-GerberBranchPathInputOrNull { 'item/juni2026' }
        Mock Invoke-GerberBranchSearch {
            [pscustomobject]@{
                NormalizedBranchPath = 'refs/heads/item/juni2026'
                Total = 2
                FoundList = @('RepoA')
                FailedList = @()
            }
        }
        Mock Show-GerberBranchFindResult {}
        Mock Wait-GerberBranchFindContinue { $false }

        Invoke-GerberBranchFindFlow

        Should -Invoke Show-GerberBranchFindHeader -Times 1
        Should -Invoke Read-GerberBranchPathInputOrNull -Times 1
        Should -Invoke Invoke-GerberBranchSearch -Times 1 -ParameterFilter {
            $NormalizedBranchPath -eq 'refs/heads/item/juni2026'
        }
        Should -Invoke Show-GerberBranchFindResult -Times 1
        Should -Invoke Wait-GerberBranchFindContinue -Times 1
    }

    It 'loops back to the path prompt when continue returns true then exits on null path' {
        Mock Show-GerberBranchFindHeader {}
        $script:pathCallCount = 0
        Mock Read-GerberBranchPathInputOrNull {
            $script:pathCallCount++
            if ($script:pathCallCount -eq 1) { return 'item/juni2026' }
            return $null
        }
        Mock Invoke-GerberBranchSearch {
            [pscustomobject]@{
                NormalizedBranchPath = 'refs/heads/item/juni2026'
                Total = 1
                FoundList = @('RepoA')
                FailedList = @()
            }
        }
        Mock Show-GerberBranchFindResult {}
        Mock Wait-GerberBranchFindContinue { $true }

        Invoke-GerberBranchFindFlow

        Should -Invoke Show-GerberBranchFindHeader -Times 2
        Should -Invoke Invoke-GerberBranchSearch -Times 1
        Should -Invoke Wait-GerberBranchFindContinue -Times 1
    }

    It 'returns without searching when Read-GerberBranchPathInputOrNull returns null' {
        Mock Show-GerberBranchFindHeader {}
        Mock Read-GerberBranchPathInputOrNull { $null }
        Mock Invoke-GerberBranchSearch {}
        Mock Show-GerberBranchFindResult {}
        Mock Wait-GerberBranchFindContinue {}

        Invoke-GerberBranchFindFlow

        Should -Invoke Invoke-GerberBranchSearch -Times 0
        Should -Invoke Show-GerberBranchFindResult -Times 0
        Should -Invoke Wait-GerberBranchFindContinue -Times 0
    }
}

Describe 'Read-GerberBranchPathInputOrNull' {
    It 'returns the typed value when no exception is thrown' {
        Mock Read-GerberCommand { 'feature/my-branch' }

        $result = Read-GerberBranchPathInputOrNull

        $result | Should -Be 'feature/my-branch'
    }

    It 'returns null when Escape is pressed during the prompt' {
        Mock Read-GerberCommand { throw (Get-GerberMenuEscapeException) }

        $result = Read-GerberBranchPathInputOrNull

        $result | Should -BeNull
    }

    It 'rethrows non-escape exceptions' {
        Mock Read-GerberCommand { throw [System.InvalidOperationException]::new('unexpected') }

        { Read-GerberBranchPathInputOrNull } | Should -Throw -ExceptionType ([System.InvalidOperationException])
    }
}

Describe 'ConvertTo-GerberNormalizedBranchPath' {
    It 'prepends refs/heads/ when path has no prefix' {
        ConvertTo-GerberNormalizedBranchPath -BranchPath 'item/juni2026' | Should -Be 'refs/heads/item/juni2026'
    }

    It 'strips a leading slash before prepending refs/heads/' {
        ConvertTo-GerberNormalizedBranchPath -BranchPath '/item/juni2026' | Should -Be 'refs/heads/item/juni2026'
    }

    It 'returns the path unchanged when it already starts with refs/heads/' {
        ConvertTo-GerberNormalizedBranchPath -BranchPath 'refs/heads/item/juni2026' | Should -Be 'refs/heads/item/juni2026'
    }

    It 'is case-insensitive when detecting existing refs/heads/ prefix' {
        ConvertTo-GerberNormalizedBranchPath -BranchPath 'REFS/HEADS/item/juni2026' | Should -Be 'REFS/HEADS/item/juni2026'
    }

    It 'trims surrounding whitespace from input' {
        ConvertTo-GerberNormalizedBranchPath -BranchPath '  item/juni2026  ' | Should -Be 'refs/heads/item/juni2026'
    }
}

Describe 'Show-GerberBranchFindResult' {
    It 'shows found repo names and summary when FoundList is non-empty' {
        Mock Clear-Host {}
        Mock Write-GerberScreenLine {}

        Show-GerberBranchFindResult -Result ([pscustomobject]@{
            NormalizedBranchPath = 'refs/heads/main'
            Total = 3
            FoundList = @('Alpha', 'Beta')
            FailedList = @()
        })

        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq '  [+] Alpha' }
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq '  [+] Beta' }
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq 'Found in 2 of 3 repositories.' }
    }

    It 'shows a neutral message when no repos contain the branch' {
        Mock Clear-Host {}
        Mock Write-GerberScreenLine {}

        Show-GerberBranchFindResult -Result ([pscustomobject]@{
            NormalizedBranchPath = 'refs/heads/nonexistent'
            Total = 5
            FoundList = @()
            FailedList = @()
        })

        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter {
            $Text -eq "No repositories contain branch 'refs/heads/nonexistent'."
        }
    }

    It 'shows a warning block when some repos failed' {
        Mock Clear-Host {}
        Mock Write-GerberScreenLine {}

        Show-GerberBranchFindResult -Result ([pscustomobject]@{
            NormalizedBranchPath = 'refs/heads/main'
            Total = 3
            FoundList = @('Alpha')
            FailedList = @('Broken')
        })

        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -like '*could not check*' }
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq '  [!] Broken' }
    }

    It 'skips the warning block when FailedList is empty' {
        Mock Clear-Host {}
        Mock Write-GerberScreenLine {}

        Show-GerberBranchFindResult -Result ([pscustomobject]@{
            NormalizedBranchPath = 'refs/heads/main'
            Total = 2
            FoundList = @('Alpha')
            FailedList = @()
        })

        Should -Invoke Write-GerberScreenLine -Times 0 -ParameterFilter { $Text -like '*could not check*' }
    }
}

Describe 'Wait-GerberBranchFindContinue' {
    It 'returns true when Enter is pressed' {
        Mock Wait-GerberContinue {}

        $result = Wait-GerberBranchFindContinue

        $result | Should -BeTrue
    }

    It 'returns false when Escape is pressed' {
        Mock Wait-GerberContinue { throw (Get-GerberMenuEscapeException) }

        $result = Wait-GerberBranchFindContinue

        $result | Should -BeFalse
    }

    It 'rethrows non-escape exceptions from Wait-GerberContinue' {
        Mock Wait-GerberContinue { throw [System.InvalidOperationException]::new('fail') }

        { Wait-GerberBranchFindContinue } | Should -Throw -ExceptionType ([System.InvalidOperationException])
    }
}

Describe 'Show-GerberBranchFindHeader' {
    It 'clears the host and writes the branch find route header' {
        Mock Start-GerberScreen {}
        Mock Write-GerberScreenLine {}

        Show-GerberBranchFindHeader

        Should -Invoke Start-GerberScreen -Times 1 -ParameterFilter { $Name -eq '/branch find' }
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq '/branch find' }
        Should -Invoke Write-GerberScreenLine -Times 2
    }
}

Describe 'Invoke-GerberBranchSearch' {
    It 'returns the search result for the given normalized branch path' {
        $expectedResult = [pscustomobject]@{
            NormalizedBranchPath = 'refs/heads/item/juni2026'
            Total = 3
            FoundList = @('RepoA', 'RepoB')
            FailedList = @()
        }
        Mock Get-GerberAdoConfiguration { [pscustomobject]@{ CredentialIdentifier = 'gerber:ado:example:pat' } }
        Mock Resolve-GerberAdoPat { 'test-pat' }
        Mock Get-GerberAdoBranchSearchResult { $expectedResult }

        $result = Invoke-GerberBranchSearch -NormalizedBranchPath 'refs/heads/item/juni2026'

        $result.NormalizedBranchPath | Should -Be 'refs/heads/item/juni2026'
        $result.FoundList.Count | Should -Be 2
        Should -Invoke Get-GerberAdoBranchSearchResult -Times 1 -ParameterFilter {
            $NormalizedBranchPath -eq 'refs/heads/item/juni2026'
        }
    }

    It 'passes the resolved pat and configuration to Get-GerberAdoBranchSearchResult' {
        Mock Get-GerberAdoConfiguration { [pscustomobject]@{ CredentialIdentifier = 'gerber:ado:example:pat' } }
        Mock Resolve-GerberAdoPat { 'resolved-pat' }
        Mock Get-GerberAdoBranchSearchResult {
            [pscustomobject]@{ NormalizedBranchPath = 'refs/heads/main'; Total = 1; FoundList = @(); FailedList = @() }
        }

        $null = Invoke-GerberBranchSearch -NormalizedBranchPath 'refs/heads/main'

        Should -Invoke Resolve-GerberAdoPat -Times 1
        Should -Invoke Get-GerberAdoBranchSearchResult -Times 1 -ParameterFilter { $Pat -eq 'resolved-pat' }
    }
}
