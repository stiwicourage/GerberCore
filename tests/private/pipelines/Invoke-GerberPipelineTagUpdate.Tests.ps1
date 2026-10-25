BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Invoke-GerberPipelineTagUpdate' {
    It 'starts the shared tag mutation flow in update mode' {
        Mock Invoke-GerberPipelineTagMutation {}

        Invoke-GerberPipelineTagUpdate

        Should -Invoke Invoke-GerberPipelineTagMutation -Times 1 -ParameterFilter {
            $Operation.Mode -eq 'update' -and
            $Operation.CommandLabel -eq '/pipelines tags update' -and
            $Operation.TracePrefix -eq 'pipelines-tags-update'
        }
    }
}
