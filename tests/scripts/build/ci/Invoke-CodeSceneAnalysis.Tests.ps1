BeforeAll {
    $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
    $script:scriptPath = Join-Path $repositoryRoot 'scripts/build/ci/Invoke-CodeSceneAnalysis.ps1'
    . $script:scriptPath

    function Write-FakeCsCoverage {
        param([string]$FailMetric = '')
        $cli = Join-Path $script:binDirectory 'cs-coverage'
        Set-Content -LiteralPath $cli -Value @(
            '#!/bin/sh'
            "echo `"`$@`" >> '$script:callLog'"
            "case `"`$*`" in *'$FailMetric'*) [ -n '$FailMetric' ] && exit 3;; esac"
            'exit 0'
        )
        chmod +x $cli
        $env:PATH = "$script:binDirectory$([IO.Path]::PathSeparator)$script:savedPath"
    }

    function Write-JaCoCoFixture {
        param([string]$Path, [switch]$Branch)
        $counter = if ($Branch) { '<counter type="BRANCH" missed="0" covered="1" />' } else { '<counter type="LINE" missed="0" covered="1" />' }
        Set-Content -LiteralPath $Path -Value "<report>$counter</report>"
    }
}

Describe 'Invoke-CodeSceneAnalysis helpers' -Tag 'BuildTooling' {
    BeforeEach {
        $script:saved = @{}
        foreach ($name in 'CS_URL', 'CS_PROJECT_ID', 'CS_ACCESS_TOKEN') {
            $script:saved[$name] = [Environment]::GetEnvironmentVariable($name)
            [Environment]::SetEnvironmentVariable($name, $null)
        }
    }

    AfterEach {
        foreach ($name in $script:saved.Keys) {
            [Environment]::SetEnvironmentVariable($name, $script:saved[$name])
        }
    }

    It 'requires configuration values' {
        { Get-RequiredCodeSceneValue -Name 'CS_URL' } | Should -Throw "*'CS_URL'*"
        $env:CS_URL = 'https://cs.example'
        Get-RequiredCodeSceneValue -Name 'CS_URL' | Should -Be 'https://cs.example'
    }

    It 'detects rate-limit and invalid-owner-token responses' {
        Test-CodeSceneRateLimitResponse -Body 'rate limit for daily analysis jobs' | Should -BeTrue
        Test-CodeSceneRateLimitResponse -Body 'other' | Should -BeFalse
        Test-CodeSceneInvalidProjectOwnerTokenResponse -Body 'OAuth token of project owner invalid' | Should -BeTrue
        Test-CodeSceneInvalidProjectOwnerTokenResponse -Body 'other' | Should -BeFalse
    }

    It 'explains analysis trigger failures' {
        Get-CodeSceneAnalysisTriggerFailureMessage -StatusCode 401 -Body 'OAuth token of project owner invalid' |
            Should -Match 'Re-authorize'
        Get-CodeSceneAnalysisTriggerFailureMessage -StatusCode 500 -Body 'x' | Should -Be 'CodeScene API call failed with HTTP 500. Review the response above for details.'
    }

    It 'requests coverage upload by switch or path only' {
        Test-CodeSceneCoverageUploadRequested | Should -BeFalse
        Test-CodeSceneCoverageUploadRequested -UploadCoverage | Should -BeTrue
        Test-CodeSceneCoverageUploadRequested -CoveragePath 'x.xml' | Should -BeTrue
    }

    It 'resolves explicit, default and missing coverage paths' {
        $explicit = Join-Path $TestDrive 'c.xml'
        Write-JaCoCoFixture -Path $explicit
        Resolve-CodeSceneCoveragePath -CoveragePath $explicit | Should -Be (Resolve-Path $explicit).Path

        Push-Location $TestDrive
        try {
            { Resolve-CodeSceneCoveragePath } | Should -Throw '*No JaCoCo coverage file*'
            $null = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'artifacts')
            Write-JaCoCoFixture -Path (Join-Path $TestDrive 'artifacts/coverage.xml')
            Resolve-CodeSceneCoveragePath | Should -Be (Join-Path (Get-Location) 'artifacts/coverage.xml')
        }
        finally { Pop-Location }
    }

    It 'detects branch counters' {
        $line = Join-Path $TestDrive 'line.xml'
        $branch = Join-Path $TestDrive 'branch.xml'
        Write-JaCoCoFixture -Path $line
        Write-JaCoCoFixture -Path $branch -Branch
        Test-JaCoCoBranchCoverageAvailable -Path $line | Should -BeFalse
        Test-JaCoCoBranchCoverageAvailable -Path $branch | Should -BeTrue
    }

    Context 'analysis trigger' {
        It 'succeeds on HTTP <Status> with body <Body>' -ForEach @(
            @{ Status = 200; Body = '{"ok":true}' }
            @{ Status = 200; Body = '' }
        ) {
            Mock Invoke-WebRequest { [pscustomobject]@{ StatusCode = $Status; Content = $Body } }
            { Invoke-CodeSceneAnalysisTrigger -CodeSceneUrl 'https://cs.example/' -ProjectId '1' -AccessToken 't' 6>$null } | Should -Not -Throw
            Should -Invoke Invoke-WebRequest -ParameterFilter { $Uri -eq 'https://cs.example/v2/projects/1/run-analysis' }
        }

        It 'throws on an error payload despite success status' {
            Mock Invoke-WebRequest { [pscustomobject]@{ StatusCode = 200; Content = '{"error":"x"}' } }
            { Invoke-CodeSceneAnalysisTrigger -CodeSceneUrl 'u' -ProjectId '1' -AccessToken 't' 6>$null } | Should -Throw '*error payload*'
        }

        It 'throws on HTTP failure' {
            Mock Invoke-WebRequest { [pscustomobject]@{ StatusCode = 500; Content = 'boom' } }
            { Invoke-CodeSceneAnalysisTrigger -CodeSceneUrl 'u' -ProjectId '1' -AccessToken 't' 6>$null } | Should -Throw '*HTTP 500*'
        }

        It 'warns and skips when rate limited' {
            Mock Invoke-WebRequest { [pscustomobject]@{ StatusCode = 429; Content = 'rate limit for daily analysis jobs' } }
            Mock Write-Warning {}
            { Invoke-CodeSceneAnalysisTrigger -CodeSceneUrl 'u' -ProjectId '1' -AccessToken 't' 6>$null } | Should -Not -Throw
            Should -Invoke Write-Warning -Times 1
        }
    }
}

Describe 'Invoke-CodeSceneAnalysis script' -Tag 'BuildTooling' {
    BeforeEach {
        $script:saved = @{}
        foreach ($name in 'CS_URL', 'CS_PROJECT_ID', 'CS_ACCESS_TOKEN') {
            $script:saved[$name] = [Environment]::GetEnvironmentVariable($name)
            [Environment]::SetEnvironmentVariable($name, $null)
        }
    }

    AfterEach {
        foreach ($name in $script:saved.Keys) {
            [Environment]::SetEnvironmentVariable($name, $script:saved[$name])
        }
    }

    It 'does nothing when no action is requested' {
        (& $script:scriptPath 6>&1 | Out-String) | Should -Match 'No CodeScene action requested'
    }

    It 'requires configuration when an action is requested' {
        { & $script:scriptPath -TriggerAnalysis } | Should -Throw "*'CS_URL'*"
    }

    Context 'with the upload CLI on PATH' {
        BeforeEach {
            $env:CS_URL = 'https://cs.example'
            $env:CS_PROJECT_ID = '1'
            $env:CS_ACCESS_TOKEN = 't'
            $script:coverage = Join-Path $TestDrive 'coverage.xml'
            $script:binDirectory = Join-Path $TestDrive 'bin'
            $null = New-Item -ItemType Directory -Path $script:binDirectory -Force
            $script:savedPath = $env:PATH
            $script:callLog = Join-Path $TestDrive 'calls.log'
            Remove-Item -LiteralPath $script:callLog -ErrorAction SilentlyContinue
        }

        AfterEach { $env:PATH = $script:savedPath }

        It 'fails when the CLI is missing' -Skip:($IsWindows) {
            Write-JaCoCoFixture -Path $script:coverage
            $env:PATH = $script:binDirectory
            { & $script:scriptPath -CoveragePath $script:coverage } | Should -Throw "*'cs-coverage' CLI was not found*"
        }

        It 'uploads line coverage and skips branch coverage without counters' -Skip:($IsWindows) {
            Write-JaCoCoFixture -Path $script:coverage
            Write-FakeCsCoverage

            $output = & $script:scriptPath -CoveragePath $script:coverage 6>&1 | Out-String

            @(Get-Content $script:callLog).Count | Should -Be 1
            $output | Should -Match 'Skipping branch-coverage upload'
        }

        It 'uploads branch coverage when counters exist' -Skip:($IsWindows) {
            Write-JaCoCoFixture -Path $script:coverage -Branch
            Write-FakeCsCoverage

            & $script:scriptPath -CoveragePath $script:coverage 6>$null

            @(Get-Content $script:callLog).Count | Should -Be 2
        }

        It 'fails when the <Metric> upload fails' -Skip:($IsWindows) -ForEach @(
            @{ Metric = 'line-coverage' }
            @{ Metric = 'branch-coverage' }
        ) {
            Write-JaCoCoFixture -Path $script:coverage -Branch
            Write-FakeCsCoverage -FailMetric $Metric

            { & $script:scriptPath -CoveragePath $script:coverage 6>$null } | Should -Throw "*$Metric upload failed*"
        }
    }
}
