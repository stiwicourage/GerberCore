BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Show-GerberPipelineReleaseLoadingScreen' {
    It 'renders the loading screen with the explicit command label' {
        Mock Show-GerberPipelineReleaseHeader {}
        Mock Write-GerberScreenLine {}

        Show-GerberPipelineReleaseLoadingScreen -CommandLabel '/pipelines tags delete' -Text 'Loading matching pipeline runs...'

        Should -Invoke Show-GerberPipelineReleaseHeader -Times 1 -ParameterFilter {
            $CommandLabel -eq '/pipelines tags delete'
        }
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter {
            $Text -eq 'Loading matching pipeline runs...'
        }
    }

    It 'requires callers to provide the command label explicitly' {
        { Show-GerberPipelineReleaseLoadingScreen -Text 'Loading...' } | Should -Throw '*CommandLabel*'
    }
}
