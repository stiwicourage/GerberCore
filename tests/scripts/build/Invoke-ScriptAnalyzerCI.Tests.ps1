$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$scriptPath = Join-Path $projectRoot 'scripts/build/Invoke-ScriptAnalyzerCI.ps1'
$env:GERBER_SCRIPTANALYZER_TEST_PROJECT_ROOT = $projectRoot
$env:GERBER_SCRIPTANALYZER_TEST_SCRIPT_PATH = $scriptPath

BeforeAll {
    $projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $scriptPath = Join-Path $projectRoot 'scripts/build/Invoke-ScriptAnalyzerCI.ps1'
    . $scriptPath
    Import-Module (Join-Path $projectRoot 'tests/TestHelpers/ScriptAnalyzerTestSupport.psm1') -Force
}

Describe 'Invoke-ScriptAnalyzerCI helpers' {
    It 'excludes only host-output diagnostics after <FailureCount> transient failures' -ForEach @(
        @{ FailureCount = 0 }
        @{ FailureCount = 1 }
    ) {
        $script:analyzerCallCount = 0
        Mock Invoke-ScriptAnalyzer {
            $script:analyzerCallCount++
            if ($script:analyzerCallCount -le $FailureCount) {
                throw [System.NullReferenceException]::new('transient analyzer failure')
            }
            return @()
        }

        Invoke-ScriptAnalyzerWithTransientRetry -Path 'sample.ps1' | Should -BeNullOrEmpty

        Should -Invoke Invoke-ScriptAnalyzer -Exactly -Times ($FailureCount + 1) -ParameterFilter {
            ($ExcludeRule -join ',') -eq 'PSAvoidUsingWriteHost'
        }
    }

    It 'allows intentional host output without excluding other real analyzer diagnostics' {
        $path = Join-Path $TestDrive 'HostOutput.ps1'
        Set-Content -LiteralPath $path -Value @(
            "Write-Host 'Intentional terminal output.'"
            'function Bad-AnalyzerFixture { }'
        )

        $result = @(Invoke-ScriptAnalyzerWithTransientRetry -Path $path)

        @($result | Where-Object RuleName -EQ 'PSAvoidUsingWriteHost') | Should -BeNullOrEmpty
        $result.RuleName | Should -Contain 'PSUseApprovedVerbs'
    }

    It 'retries one transient analyzer null-reference failure' {
        $script:analyzerCallCount = 0
        Mock Invoke-ScriptAnalyzer {
            $script:analyzerCallCount++
            if ($script:analyzerCallCount -eq 1) {
                throw [System.NullReferenceException]::new('transient analyzer failure')
            }
            return @()
        }

        $result = @(Invoke-ScriptAnalyzerWithTransientRetry -Path 'sample.ps1')

        $result | Should -BeNullOrEmpty
        Should -Invoke Invoke-ScriptAnalyzer -Times 2
    }

    It 'does not retry non-transient analyzer failures' {
        Mock Invoke-ScriptAnalyzer {
            throw [System.InvalidOperationException]::new('persistent analyzer failure')
        }

        {
            Invoke-ScriptAnalyzerWithTransientRetry -Path 'sample.ps1'
        } | Should -Throw '*persistent analyzer failure*'

        Should -Invoke Invoke-ScriptAnalyzer -Times 1
    }

    It 'includes tests and excludes generated directories from the analyzer scope' {
        $repositoryRoot = Join-Path $TestDrive 'repo'
        $null = New-Item -ItemType Directory -Path (Join-Path $repositoryRoot 'src') -Force
        $null = New-Item -ItemType Directory -Path (Join-Path $repositoryRoot 'tests') -Force
        $null = New-Item -ItemType Directory -Path (Join-Path $repositoryRoot 'scripts') -Force
        $null = New-Item -ItemType Directory -Path (Join-Path $repositoryRoot 'artifacts') -Force
        $null = New-Item -ItemType Directory -Path (Join-Path $repositoryRoot 'dist') -Force
        Set-Content -LiteralPath (Join-Path $repositoryRoot 'src/One.ps1') -Value 'function Get-One { }'
        Set-Content -LiteralPath (Join-Path $repositoryRoot 'tests/One.Tests.ps1') -Value 'Describe "One" { }'
        Set-Content -LiteralPath (Join-Path $repositoryRoot 'artifacts/Generated.ps1') -Value 'function Get-Generated { }'
        Set-Content -LiteralPath (Join-Path $repositoryRoot 'dist/Generated.ps1') -Value 'function Get-DistGenerated { }'

        $pathList = @(Get-ScriptAnalyzerAnalysisPathList -RepositoryRoot $repositoryRoot)
        $relativePathList = @(
            $pathList | ForEach-Object {
                [System.IO.Path]::GetRelativePath($repositoryRoot, $_).Replace('\', '/')
            }
        )

        $relativePathList | Should -Contain 'src/One.ps1'
        $relativePathList | Should -Contain 'tests/One.Tests.ps1'
        $relativePathList | Should -Not -Contain 'artifacts/Generated.ps1'
        $relativePathList | Should -Not -Contain 'dist/Generated.ps1'
    }

    It 'converts ScriptAnalyzer results to repository-relative finding records' {
        $resultList = @(
            Get-FakeScriptAnalyzerResult -PropertyOverrides @{
                Severity     = 'Warning'
                RuleName     = 'Rule.One'
                RelativePath = 'src/one.ps1'
                Line         = 9
                Message      = 'Repeated finding.'
            }
        )

        $findingList = ConvertTo-ScriptAnalyzerFindingRecordList -ResultList $resultList -RepositoryRoot $projectRoot

        $findingList[0].Severity | Should -Be 'Warning'
        $findingList[0].RuleName | Should -Be 'Rule.One'
        $findingList[0].RelativePath | Should -Be 'src/one.ps1'
        $findingList[0].Line | Should -Be 9
    }

    It 'formats an empty report section without a binding error' {
        $section = Get-ScriptAnalyzerReportSection `
            -Title 'Findings by severity' `
            -ItemList @() `
            -Formatter { param($item) $item }

        $section | Should -Be 'Findings by severity: none.'
    }

    It 'does not reference the removed baseline mechanism' {
        $scriptText = Get-Content -LiteralPath $scriptPath -Raw

        $scriptText | Should -Not -Match 'PSScriptAnalyzerBaseline'
        $scriptText | Should -Not -Match 'UpdateBaseline'
    }
}

Describe 'Invoke-ScriptAnalyzerCI' {
    BeforeEach {
        Mock Import-ScriptAnalyzerModule { [version]'1.25.0' }
        Mock Confirm-ScriptAnalyzerVersion {}
        Mock Get-ScriptAnalyzerRepositoryRoot { $projectRoot }
        Mock Get-ScriptAnalyzerAnalysisPathList { @('src/one.ps1', 'tests/one.Tests.ps1') }
        Mock New-Item {}
        Mock Write-ScriptAnalyzerReport {}
    }

    It 'returns success when no findings exist' {
        Mock Get-ScriptAnalyzerResultList { @() }

        $result = Invoke-ScriptAnalyzerCI -OutputDirectory './artifacts'

        $result | Should -BeLike 'PSScriptAnalyzer: 0 findings*'
    }

    It 'fails when any finding exists for <Severity>' -ForEach @(
        @{ Severity = 'Error' }
        @{ Severity = 'Warning' }
        @{ Severity = 'Information' }
    ) {
        Mock Get-ScriptAnalyzerResultList {
            @(
                Get-FakeScriptAnalyzerResult -PropertyOverrides @{
                    Severity     = $Severity
                    RuleName     = "Rule.$Severity"
                    RelativePath = 'src/test.ps1'
                    Line         = 4
                    Message      = "$Severity finding."
                }
            )
        }

        {
            Invoke-ScriptAnalyzerCI -OutputDirectory './artifacts'
        } | Should -Throw '*PSScriptAnalyzer reported 1 finding(s).*'
    }

    It 'fails when multiple findings exist' {
        Mock Get-ScriptAnalyzerResultList {
            @(
                Get-FakeScriptAnalyzerResult -PropertyOverrides @{
                    Severity = 'Warning'
                    RuleName = 'Rule.One'
                }
                Get-FakeScriptAnalyzerResult -PropertyOverrides @{
                    Severity = 'Information'
                    RuleName = 'Rule.Two'
                    Line     = 8
                }
            )
        }

        {
            Invoke-ScriptAnalyzerCI -OutputDirectory './artifacts'
        } | Should -Throw '*PSScriptAnalyzer reported 2 finding(s).*'
    }

    It 'fails when analyzer execution throws' {
        Mock Get-ScriptAnalyzerResultList { throw 'Analyzer execution failed.' }

        {
            Invoke-ScriptAnalyzerCI -OutputDirectory './artifacts'
        } | Should -Throw '*Analyzer execution failed.*'
    }

    It 'fails with a clear error when the analyzer module is missing' {
        Mock Import-ScriptAnalyzerModule { throw 'PSScriptAnalyzer 1.25.0 is required but could not be imported. Missing module.' }

        {
            Invoke-ScriptAnalyzerCI -OutputDirectory './artifacts'
        } | Should -Throw '*required but could not be imported*'
    }
}

Describe 'Invoke-ScriptAnalyzerCI script process behavior' {
    It 'returns exit code 0 when no findings exist' {
        $commandPath = Join-Path $TestDrive ([guid]::NewGuid().ToString('N') + '.ps1')
        @(
            'Set-Location "{0}"' -f $projectRoot
            '& "{0}" -OutputDirectory "./artifacts"' -f $scriptPath
            'exit $LASTEXITCODE'
        ) | Set-Content -LiteralPath $commandPath

        $process = Invoke-PwshProcess -ArgumentList @('-NoLogo', '-NoProfile', '-File', $commandPath)
        $result = @($process.StandardOutput -split [Environment]::NewLine | Where-Object { $_ -ne '' })

        $process.ExitCode | Should -Be 0
        @($result)[-1] | Should -BeLike 'PSScriptAnalyzer: 0 findings*'
        $process.StandardError | Should -BeNullOrEmpty
    }

    It 'returns exit code 1 when findings exist' {
        $harness = Get-ScriptAnalyzerHarness -Findings @(
            [pscustomobject]@{
                Severity     = 'Information'
                RuleName     = 'Rule.Info'
                RelativePath = 'src/Sample.ps1'
                Line         = 1
                Message      = 'Info finding.'
            }
        )
        $commandPath = Join-Path $TestDrive ([guid]::NewGuid().ToString('N') + '.ps1')
        @(
            '$env:PSModulePath = "{0}"' -f $harness.ModuleRoot
            '$env:GERBER_FAKE_REPOSITORY_ROOT = "{0}"' -f $harness.RepositoryRoot
            '& "{0}" -OutputDirectory "./artifacts"' -f $harness.ScriptPath
            'exit $LASTEXITCODE'
        ) | Set-Content -LiteralPath $commandPath

        $process = Invoke-PwshProcess -ArgumentList @('-NoLogo', '-NoProfile', '-File', $commandPath)

        $process.ExitCode | Should -Be 1
    }

    It 'returns exit code 1 when the analyzer dependency is missing' {
        $repoRoot = Join-Path $TestDrive 'missing-module-repo'
        $null = New-Item -ItemType Directory -Path (Join-Path $repoRoot 'scripts/build') -Force
        $null = New-Item -ItemType Directory -Path (Join-Path $repoRoot 'src') -Force
        Copy-Item -LiteralPath $scriptPath -Destination (Join-Path $repoRoot 'scripts/build/Invoke-ScriptAnalyzerCI.ps1')
        Set-Content -LiteralPath (Join-Path $repoRoot 'src/Sample.ps1') -Value "function Get-Sample { 'ok' }"
        $emptyModuleRoot = Join-Path $TestDrive 'empty-modules'
        $null = New-Item -ItemType Directory -Path $emptyModuleRoot -Force
        $commandPath = Join-Path $TestDrive ([guid]::NewGuid().ToString('N') + '.ps1')
        @(
            '$env:PSModulePath = "{0}"' -f $emptyModuleRoot
            '& "{0}" -OutputDirectory "./artifacts"' -f (Join-Path $repoRoot 'scripts/build/Invoke-ScriptAnalyzerCI.ps1')
            'exit $LASTEXITCODE'
        ) | Set-Content -LiteralPath $commandPath

        $process = Invoke-PwshProcess -ArgumentList @('-NoLogo', '-NoProfile', '-File', $commandPath)
        $output = $process.StandardError

        $process.ExitCode | Should -Be 1
        $output | Should -Match 'required but could not be imported'
    }
}
