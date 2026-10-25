BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Show-GerberPipelinesTagsView' {
    It 'returns when Escape is pressed at the pipelines tags prompt' {
        Mock Get-GerberMenuSubcommand { throw (Get-GerberMenuEscapeException) }
        Mock Invoke-GerberPipelineTagDelete {}
        Mock Invoke-GerberPipelineTagUpdate {}

        Show-GerberPipelinesTagsView -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Invoke-GerberPipelineTagDelete -Times 0
        Should -Invoke Invoke-GerberPipelineTagUpdate -Times 0
    }

    It 'opens delete when subcommand is delete' {
        $script:callCount = 0
        Mock Get-GerberMenuSubcommand {
            $script:callCount++
            if ($script:callCount -eq 1) {
                return 'delete'
            }

            throw (Get-GerberMenuEscapeException)
        }
        Mock Invoke-GerberPipelineTagDelete {}

        Show-GerberPipelinesTagsView -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Invoke-GerberPipelineTagDelete -Times 1
    }

    It 'opens update when subcommand is update' {
        $script:callCount = 0
        Mock Get-GerberMenuSubcommand {
            $script:callCount++
            if ($script:callCount -eq 1) {
                return 'update'
            }

            throw (Get-GerberMenuEscapeException)
        }
        Mock Invoke-GerberPipelineTagUpdate {}

        Show-GerberPipelinesTagsView -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Invoke-GerberPipelineTagUpdate -Times 1
    }

    It 'throws for unknown pipelines tags subcommands' {
        Mock Get-GerberMenuSubcommand { 'unknown' }

        { Show-GerberPipelinesTagsView -Command ([pscustomobject]@{ Arguments = @() }) } |
            Should -Throw -ExceptionType ([System.ArgumentException]) -ExpectedMessage "Unknown pipelines tags subcommand 'unknown'. Use /pipelines tags update or /pipelines tags delete."
    }
}
