BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberPipelineReleaseContext' {
    It 'uses the explicit command label when resolving the Azure DevOps PAT' {
        Mock Get-GerberAdoConfiguration { [pscustomobject]@{ CredentialIdentifier = 'gerber:ado:example:pat' } }
        Mock Resolve-GerberAdoPat { 'pat-value' }

        $result = Get-GerberPipelineReleaseContext -CommandLabel '/pipelines tags update'

        $result.Configuration.CredentialIdentifier | Should -Be 'gerber:ado:example:pat'
        $result.Pat | Should -Be 'pat-value'
        Should -Invoke Resolve-GerberAdoPat -Times 1 -ParameterFilter {
            $CommandLabel -eq '/pipelines tags update'
        }
    }

    It 'requires callers to provide the command label explicitly' {
        { Get-GerberPipelineReleaseContext } | Should -Throw '*CommandLabel*'
    }
}
