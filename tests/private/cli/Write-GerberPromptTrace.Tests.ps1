BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Write-GerberPromptTrace' {
    BeforeEach {
        [Environment]::SetEnvironmentVariable('GERBER_PROMPT_TRACE', $null)
    }

    It 'detects prompt tracing from the environment variable' {
        [Environment]::SetEnvironmentVariable('GERBER_PROMPT_TRACE', 'true')

        (Test-GerberPromptTraceEnabled) | Should -BeTrue
    }

    It 'writes prompt trace entries to the local .gerber log file' {
        $tracePath = Join-Path $TestDrive '.gerber/prompt-debug.log'
        Mock Resolve-GerberPromptTracePath { $tracePath }
        [Environment]::SetEnvironmentVariable('GERBER_PROMPT_TRACE', '1')

        Write-GerberPromptTrace -EventName 'trace-test' -Data @{ Buffer = '/te' }

        (Test-Path -LiteralPath $tracePath) | Should -BeTrue
        (Get-Content -LiteralPath $tracePath -Raw) | Should -Match 'trace-test'
        (Get-Content -LiteralPath $tracePath -Raw) | Should -Match 'SessionId'
    }

    It 'reuses one SessionId across related trace events in the same session' {
        $tracePath = Join-Path $TestDrive '.gerber/session/prompt-debug.log'
        Mock Resolve-GerberPromptTracePath { $tracePath }
        [Environment]::SetEnvironmentVariable('GERBER_PROMPT_TRACE', '1')

        Write-GerberPromptTrace -EventName 'trace-test-1' -Data @{ BufferLength = 1 }
        Write-GerberPromptTrace -EventName 'trace-test-2' -Data @{ BufferLength = 2 }

        $entryList = @(Get-Content -LiteralPath $tracePath | ForEach-Object { $_ | ConvertFrom-Json })

        $entryList.Count | Should -Be 2
        $entryList[0].SessionId | Should -Be $entryList[1].SessionId
    }

    It 'creates a SessionId when tracing runs under strict mode without a preexisting script variable' {
        $tracePath = Join-Path $TestDrive '.gerber/strict/prompt-debug.log'
        Mock Resolve-GerberPromptTracePath { $tracePath }
        [Environment]::SetEnvironmentVariable('GERBER_PROMPT_TRACE', '1')
        Remove-Variable -Name GerberPromptTraceSessionId -Scope Script -ErrorAction SilentlyContinue

        & {
            Set-StrictMode -Version Latest
            Write-GerberPromptTrace -EventName 'trace-strict' -Data @{ BufferLength = 1 }
        }

        (Test-Path -LiteralPath $tracePath) | Should -BeTrue
    }

    It 'builds a prompt-debug.log path relative to the config directory' {
        Mock Resolve-GerberConfigPath { Join-Path $TestDrive '.gerber/config.json' }

        $result = Resolve-GerberPromptTracePath

        $result | Should -Match 'prompt-debug\.log$'
    }

    It 'swallows trace file write failures' {
        [Environment]::SetEnvironmentVariable('GERBER_PROMPT_TRACE', '1')
        Mock Resolve-GerberPromptTracePath { Join-Path $TestDrive '.gerber/prompt-debug.log' }
        Mock Add-Content { throw 'Disk full.' }

        { Write-GerberPromptTrace -EventName 'trace-test' -Data @{ BufferLength = 1 } } | Should -Not -Throw
    }
}
