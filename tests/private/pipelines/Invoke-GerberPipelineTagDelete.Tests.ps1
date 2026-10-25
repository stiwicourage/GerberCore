BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Invoke-GerberPipelineTagDelete' {
    It 'starts the shared tag mutation flow in delete mode' {
        Mock Invoke-GerberPipelineTagMutation {}

        Invoke-GerberPipelineTagDelete

        Should -Invoke Invoke-GerberPipelineTagMutation -Times 1 -ParameterFilter {
            $Operation.Mode -eq 'delete' -and
            $Operation.CommandLabel -eq '/pipelines tags delete' -and
            $Operation.TracePrefix -eq 'pipelines-tags-delete'
        }
    }
}
