BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoPipelineRunTimeline' {
    It 'requests the build timeline and normalizes the returned records' {
        $configuration = [pscustomobject]@{
            CollectionUri          = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName            = 'ExampleProject'
            CredentialIdentifier = 'gerber:ado:example:pat'
        }
        Mock Invoke-GerberAdoRestRequest {
            [pscustomobject]@{
                records = @(
                    [pscustomobject]@{
                        id = 'approval-1'
                        parentId = 'checkpoint-1'
                        type = 'Checkpoint.Approval'
                        name = 'Review'
                        identifier = 'Checkpoint.Approval'
                        state = 'completed'
                        result = 'succeeded'
                    }
                )
            }
        }

        $result = @(Get-GerberAdoPipelineRunTimeline -Configuration $configuration -Pat 'pat' -BuildId 72513)

        $result[0].Type | Should -Be 'Checkpoint.Approval'
        $result[0].Identifier | Should -Be 'Checkpoint.Approval'
        $result[0].State | Should -Be 'completed'
        $result[0].Result | Should -Be 'succeeded'
        Should -Invoke Invoke-GerberAdoRestRequest -Times 1 -ParameterFilter {
            $Uri.AbsoluteUri -eq 'https://ado.example.test/ExampleProject/ExampleProject/_apis/build/builds/72513/timeline?api-version=7.1'
        }
    }

    Describe 'Get-GerberAdoPipelineRunTimeline helpers' {
        It 'returns empty record lists when the response is null or lacks records' {
            @(Get-GerberAdoPipelineRunTimelineRecordList -Response $null).Count | Should -Be 0
            @(Get-GerberAdoPipelineRunTimelineRecordList -Response ([pscustomobject]@{})).Count | Should -Be 0
        }

        It 'reads record values from hashtables and returns empty strings for missing properties' {
            @(Get-GerberAdoPipelineRunTimelineRecordList -Response @{ records = @(@{ id = 'approval-1' }) }).Count | Should -Be 1
            (Get-GerberAdoPipelineRunTimelinePropertyValue -Record $null -PropertyName 'id') | Should -Be ''
            (Get-GerberAdoPipelineRunTimelinePropertyValue -Record @{ id = 'approval-1' } -PropertyName 'id') | Should -Be 'approval-1'
            (Get-GerberAdoPipelineRunTimelinePropertyValue -Record ([pscustomobject]@{}) -PropertyName 'id') | Should -Be ''
        }
    }
}
