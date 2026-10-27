BeforeAll {
    $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
    . (Join-Path $repositoryRoot 'scripts/build/ci/Invoke-NativeCredentialPlatformCI.ps1')

    function Write-NativeTestReport {
        param([string]$Path, [string]$Attribute = '', [string]$Value = '')
        [xml]$report = '<test-results total="13" errors="0" failures="0" inconclusive="0" skipped="0"><test-suite executed="True" result="Success" success="True" total="13" passed="2" failed="0" inconclusive="0" skipped="0" /></test-results>'
        if ($Attribute) {
            $report.SelectSingleNode('//test-suite').SetAttribute($Attribute, $Value)
        }
        $report.Save($Path)
        # Coarse filesystem timestamps can predate the runner's start time on Linux.
        (Get-Item -LiteralPath $Path).LastWriteTimeUtc = [datetime]::UtcNow.AddSeconds(5)
    }

    function Get-NativeCredentialLinuxShell {
        $workflow = Get-Content (Join-Path $repositoryRoot '.github/workflows/Run-Platform-Matrix.yml') -Raw
        $pattern = '(?ms)^      - name: Run Linux native credentials.*?^        run: \|\r?\n(?<body>.*?)(?=^      - name:)'
        $match = [regex]::Match($workflow, $pattern)
        if (-not $match.Success) {
            throw 'The Linux native workflow shell block was not found.'
        }
        return $match.Groups['body'].Value -replace '(?m)^ {10}', ''
    }
}

Describe 'Native credential platform lane' -Tag 'BuildTooling' {
    BeforeEach {
        $script:reportPath = Join-Path $TestDrive 'TestResults.xml'
        $script:savedOptIn = $env:GERBER_RUN_NATIVE_CREDENTIAL_TESTS
        $script:savedStore = $env:GCM_CREDENTIAL_STORE
        $env:GERBER_RUN_NATIVE_CREDENTIAL_TESTS = 'previous-opt-in'
        $env:GCM_CREDENTIAL_STORE = 'previous-store'
        Mock Get-NativeCredentialRuntime {
            [pscustomobject]@{ Version = [version]'7.4'; OS = 'Linux'; Architecture = 'X64' }
        }
    }

    AfterEach {
        $env:GERBER_RUN_NATIVE_CREDENTIAL_TESTS = $savedOptIn
        $env:GCM_CREDENTIAL_STORE = $savedStore
    }

    It 'accepts exactly two executed native cases when the Nova raw total includes NotRun cases' {
        Write-NativeTestReport -Path $reportPath
        { Assert-NativeCredentialReport -Path $reportPath -NotBefore ([datetime]::UtcNow.AddMinutes(-1)) } |
            Should -Not -Throw
    }

    It 'rejects <Attribute>=<Value> rather than accepting skipped or broad runs' -ForEach @(
        @{ Attribute = 'total'; Value = '1' }
        @{ Attribute = 'passed'; Value = '0' }
        @{ Attribute = 'failed'; Value = '1' }
        @{ Attribute = 'skipped'; Value = '2' }
        @{ Attribute = 'inconclusive'; Value = '1' }
        @{ Attribute = 'executed'; Value = 'False' }
        @{ Attribute = 'result'; Value = 'Failure' }
        @{ Attribute = 'success'; Value = 'False' }
    ) {
        Write-NativeTestReport -Path $reportPath -Attribute $Attribute -Value $Value
        { Assert-NativeCredentialReport -Path $reportPath -NotBefore ([datetime]::UtcNow.AddMinutes(-1)) } |
            Should -Throw
    }

    It 'rejects a missing or malformed report' -ForEach @('missing', 'malformed') {
        if ($_ -eq 'malformed') {
            Set-Content -LiteralPath $reportPath -Value '<broken'
        }
        { Assert-NativeCredentialReport -Path $reportPath -NotBefore ([datetime]::UtcNow.AddMinutes(-1)) } |
            Should -Throw
    }

    It 'rejects a stale report' {
        Write-NativeTestReport -Path $reportPath
        (Get-Item -LiteralPath $reportPath).LastWriteTimeUtc = [datetime]::UtcNow.AddDays(-1)
        { Assert-NativeCredentialReport -Path $reportPath -NotBefore ([datetime]::UtcNow.AddMinutes(-1)) } |
            Should -Throw '*fresh*'
    }

    It 'rejects an invalid root counter <_>' -ForEach @('total', 'errors', 'failures', 'inconclusive', 'skipped') {
        Write-NativeTestReport -Path $reportPath
        [xml]$report = Get-Content -LiteralPath $reportPath -Raw
        $report.DocumentElement.SetAttribute($_, '9')
        $report.Save($reportPath)
        { Assert-NativeCredentialReport -Path $reportPath -NotBefore ([datetime]::UtcNow.AddMinutes(-1)) } |
            Should -Throw
    }

    It 'rejects a broad successful execution rather than trusting a green summary' {
        Write-NativeTestReport -Path $reportPath -Attribute passed -Value '13'
        { Assert-NativeCredentialReport -Path $reportPath -NotBefore ([datetime]::UtcNow.AddMinutes(-1)) } |
            Should -Throw
    }

    It 'rejects malformed count <Value> in <Element>' -ForEach @(
        @{ Element = 'test-results'; Value = '-1' }
        @{ Element = 'test-results'; Value = 'not-a-number' }
        @{ Element = 'test-results'; Value = '' }
        @{ Element = 'test-results'; Value = '2147483648' }
        @{ Element = 'test-suite'; Value = '-1' }
        @{ Element = 'test-suite'; Value = 'not-a-number' }
        @{ Element = 'test-suite'; Value = '' }
        @{ Element = 'test-suite'; Value = '2147483648' }
    ) {
        Write-NativeTestReport -Path $reportPath
        [xml]$report = Get-Content -LiteralPath $reportPath -Raw
        $report.SelectSingleNode("//$Element").SetAttribute('total', $Value)
        $report.Save($reportPath)
        { Assert-NativeCredentialReport -Path $reportPath -NotBefore ([datetime]::UtcNow.AddMinutes(-1)) } |
            Should -Throw
    }

    It 'rejects a raw total smaller than its executed count' {
        Write-NativeTestReport -Path $reportPath
        [xml]$report = Get-Content -LiteralPath $reportPath -Raw
        $report.DocumentElement.SetAttribute('total', '1')
        $report.SelectSingleNode('//test-suite').SetAttribute('total', '1')
        $report.Save($reportPath)
        { Assert-NativeCredentialReport -Path $reportPath -NotBefore ([datetime]::UtcNow.AddMinutes(-1)) } |
            Should -Throw
    }

    It 'rejects <_> summary suites instead of inventing a passing selection' -ForEach @(0, 2) {
        Write-NativeTestReport -Path $reportPath
        [xml]$report = Get-Content -LiteralPath $reportPath -Raw
        $suite = $report.SelectSingleNode('//test-suite')
        if ($_ -eq 0) {
            $null = $report.DocumentElement.RemoveChild($suite)
        } else {
            $null = $report.DocumentElement.AppendChild($suite.CloneNode($true))
        }
        $report.Save($reportPath)
        { Assert-NativeCredentialReport -Path $reportPath -NotBefore ([datetime]::UtcNow.AddMinutes(-1)) } |
            Should -Throw
    }

    It 'fails before tests if an old report cannot be removed' {
        Write-NativeTestReport -Path $reportPath
        Mock Remove-Item { throw 'cannot clear report' }
        Mock Test-NovaBuild {}
        { Invoke-NativeCredentialTest -ReportPath $reportPath } | Should -Throw '*cannot clear report*'
        Should -Invoke Test-NovaBuild -Times 0 -Exactly
    }

    It 'removes stale results, selects only real-native tests and restores both environment values' {
        Write-NativeTestReport -Path $reportPath
        Mock Test-NovaBuild {
            Test-Path -LiteralPath $reportPath | Should -BeFalse
            $env:GERBER_RUN_NATIVE_CREDENTIAL_TESTS | Should -Be '1'
            $env:GCM_CREDENTIAL_STORE | Should -BeNullOrEmpty
            Write-NativeTestReport -Path $reportPath
        }
        Invoke-NativeCredentialTest -ReportPath $reportPath
        Should -Invoke Test-NovaBuild -Times 1 -Exactly -ParameterFilter {
            ($TagFilter -join ',') -eq 'NativeCredentialStore' -and
            $OutputVerbosity -eq 'Detailed' -and $OutputRenderMode -eq 'Ansi'
        }
        $env:GERBER_RUN_NATIVE_CREDENTIAL_TESTS | Should -Be 'previous-opt-in'
        $env:GCM_CREDENTIAL_STORE | Should -Be 'previous-store'
    }

    It 'restores the environment when the native test runner fails' {
        Mock Test-NovaBuild { throw 'native test failed' }
        { Invoke-NativeCredentialTest -ReportPath $reportPath } | Should -Throw '*native test failed*'
        $env:GERBER_RUN_NATIVE_CREDENTIAL_TESTS | Should -Be 'previous-opt-in'
        $env:GCM_CREDENTIAL_STORE | Should -Be 'previous-store'
    }

    It 'restores the environment when the native report is rejected' {
        Mock Test-NovaBuild { Write-NativeTestReport -Path $reportPath -Attribute skipped -Value '2' }
        { Invoke-NativeCredentialTest -ReportPath $reportPath } | Should -Throw
        $env:GERBER_RUN_NATIVE_CREDENTIAL_TESTS | Should -Be 'previous-opt-in'
        $env:GCM_CREDENTIAL_STORE | Should -Be 'previous-store'
    }

    It 'cannot reuse an old passing report when the runner produces no report' {
        Write-NativeTestReport -Path $reportPath
        Mock Test-NovaBuild {}
        { Invoke-NativeCredentialTest -ReportPath $reportPath } | Should -Throw
        Test-Path -LiteralPath $reportPath | Should -BeFalse
    }

    It 'restores absent environment values after a successful run' {
        $env:GERBER_RUN_NATIVE_CREDENTIAL_TESTS = $null
        $env:GCM_CREDENTIAL_STORE = $null
        Mock Test-NovaBuild { Write-NativeTestReport -Path $reportPath }
        Invoke-NativeCredentialTest -ReportPath $reportPath
        $env:GERBER_RUN_NATIVE_CREDENTIAL_TESTS | Should -BeNullOrEmpty
        $env:GCM_CREDENTIAL_STORE | Should -BeNullOrEmpty
    }

    It 'imports the PMU minimum from project metadata after a version change' {
        $script:expectedMinimum = '2.3.4'
        Mock Assert-NativeCredentialRunner {}
        Mock Invoke-NovaBuild {}
        Mock Invoke-NativeCredentialTest {}
        Mock Get-Content {
            @{ Manifest = @{ RequiredModules = @(@{ ModuleName = 'PSModuleUpdate'; ModuleVersion = $script:expectedMinimum }) } } |
                ConvertTo-Json -Depth 5
        }
        $script:pmuImport = $null
        Mock Import-Module {
            $script:pmuImport = @{ Name = $Name; MinimumVersion = $MinimumVersion }
        }

        Invoke-NativeCredentialPlatformCI

        $script:pmuImport.Name | Should -Be 'PSModuleUpdate'
        $script:pmuImport.MinimumVersion | Should -Be $script:expectedMinimum
    }

    It 'builds before opting in and restores the working directory on failure' {
        $originalLocation = Get-Location
        Mock Assert-NativeCredentialRunner {}
        Mock Import-Module {}
        Mock Invoke-NovaBuild {
            $env:GERBER_RUN_NATIVE_CREDENTIAL_TESTS | Should -Be 'previous-opt-in'
        }
        Mock Invoke-NativeCredentialTest { throw 'native lane failed' }
        { Invoke-NativeCredentialPlatformCI } | Should -Throw '*native lane failed*'
        Should -Invoke Invoke-NovaBuild -Times 1 -Exactly
        (Get-Location).Path | Should -Be $originalLocation.Path
    }
}

Describe 'Native credential hosted runner safety' -Tag 'BuildTooling' {
    BeforeEach {
        $savedRunnerEnvironment = @{}
        foreach ($name in @('GITHUB_ACTIONS', 'RUNNER_ENVIRONMENT', 'RUNNER_OS', 'RUNNER_ARCH')) {
            $savedRunnerEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
        }
        $env:GITHUB_ACTIONS = 'true'
        $env:RUNNER_ENVIRONMENT = 'github-hosted'
        $env:RUNNER_OS = 'Linux'
        $env:RUNNER_ARCH = 'X64'
        Mock Get-NativeCredentialRuntime {
            [pscustomobject]@{ Version = [version]'7.4'; OS = 'Linux'; Architecture = 'X64' }
        }
    }

    AfterEach {
        foreach ($name in $savedRunnerEnvironment.Keys) {
            [Environment]::SetEnvironmentVariable($name, $savedRunnerEnvironment[$name])
        }
    }

    It 'accepts a matching hosted runner' {
        { Assert-NativeCredentialRunner } | Should -Not -Throw
    }

    It 'rejects <Name>=<Value> before build or credentials' -ForEach @(
        @{ Name = 'GITHUB_ACTIONS'; Value = '' }
        @{ Name = 'RUNNER_ENVIRONMENT'; Value = 'self-hosted' }
        @{ Name = 'RUNNER_OS'; Value = 'Windows' }
        @{ Name = 'RUNNER_ARCH'; Value = 'ARM64' }
    ) {
        [Environment]::SetEnvironmentVariable($Name, $Value)
        Mock Invoke-NovaBuild {}
        { Invoke-NativeCredentialPlatformCI } | Should -Throw
        Should -Invoke Invoke-NovaBuild -Times 0 -Exactly
    }

    It 'rejects PowerShell below 7.4' {
        Mock Get-NativeCredentialRuntime {
            [pscustomobject]@{ Version = [version]'7.3'; OS = 'Linux'; Architecture = 'X64' }
        }
        { Assert-NativeCredentialRunner } | Should -Throw '*7.4*'
    }
}

# Exercise the existing native scenario with a fake module, never a host vault.
Describe 'Selected native scenario cleanup' -Tag 'BuildTooling' {
    It 'removes its owned credential when the first read fails after a successful write' {
        $state = [pscustomobject]@{ Written = ''; Removed = '' }
        $fakeModule = New-Module -ScriptBlock {
            param($State)
            $script:CredentialState = $State
            function Set-GerberCredential {
                [CmdletBinding(SupportsShouldProcess)]
                param($Identifier, $Secret)
                if ($PSCmdlet.ShouldProcess($Identifier, 'Record test write')) {
                    $script:CredentialState.Written = $Identifier
                }
                $Secret | Out-Null
            }
            function Get-GerberCredential {
                param($Identifier)
                throw "deliberate read failure: $Identifier"
            }
            function Remove-GerberCredential {
                [CmdletBinding(SupportsShouldProcess)]
                param($Identifier)
                if ($PSCmdlet.ShouldProcess($Identifier, 'Record test cleanup')) {
                    $script:CredentialState.Removed = $Identifier
                }
            }

        } -ArgumentList $state
        Mock Import-Module { $fakeModule }
        $path = Join-Path $repositoryRoot 'tests/public/CredentialService.Integration.Tests.ps1'
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$null)
        $scenario = $ast.Find({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -eq 'It' -and
            $node.CommandElements[1].Value -eq 'round-trips an isolated native credential when explicitly enabled'
        }, $true)
        $body = $scenario.CommandElements[-1].ScriptBlock.GetScriptBlock()
        { & $body } | Should -Throw '*deliberate read failure*'
        $state.Written | Should -Match '^gerber:test:integration:[a-f0-9]{32}$'
        $state.Removed | Should -Be $state.Written
    }
}

# Execute the workflow's actual Unix shell with native-session commands replaced.
Describe 'Linux native workflow module isolation' -Tag 'BuildTooling' {
    It 'preserves CI module lookup and cleans owned XDG data (capture=<CaptureExit>, lane=<LaneExit>)' -Skip:$IsWindows -ForEach @(
        @{ CaptureExit = 0; LaneExit = 0; ExpectedExit = 0 }
        @{ CaptureExit = 0; LaneExit = 7; ExpectedExit = 7 }
        @{ CaptureExit = 9; LaneExit = 0; ExpectedExit = 9 }
    ) {
        $tempRoot = Join-Path $TestDrive 'linux-lane-temp'
        $null = New-Item -ItemType Directory -Path $tempRoot -Force
        $modulePath = "$tempRoot/original data/powershell/Modules:/ci/system/Modules"
        $stubs = @'
RUNNER_TEMP="$1"
XDG_DATA_HOME="$RUNNER_TEMP/original-xdg"
original_xdg="$XDG_DATA_HOME"
fixture_module_path="$2"
fixture_capture_exit="$3"
fixture_lane_exit="$4"
unset PSModulePath
pwsh() {
  [[ "$XDG_DATA_HOME" == "$original_xdg" ]] || return 21
  [[ "$fixture_capture_exit" == 0 ]] || return "$fixture_capture_exit"
  printf '%s\n' "$fixture_module_path"
}
xvfb-run() {
  [[ "${PSModulePath-}" == "$fixture_module_path" ]] || return 22
  [[ "$XDG_DATA_HOME" == "$RUNNER_TEMP"/gerber-native-data.* ]] || return 23
  printf 'module-path-preserved\n'
  return "$fixture_lane_exit"
}
'@
        $shell = "$stubs`n$(Get-NativeCredentialLinuxShell)"
        $output = & bash -c $shell 'gerber-linux-lane-fixture' $tempRoot $modulePath $CaptureExit $LaneExit
        $LASTEXITCODE | Should -Be $ExpectedExit
        if ($CaptureExit -eq 0) {
            $output | Should -Contain 'module-path-preserved'
        } else {
            $output | Should -BeNullOrEmpty
        }
        @(Get-ChildItem -LiteralPath $tempRoot -Force).Count | Should -Be 0
    }
}
