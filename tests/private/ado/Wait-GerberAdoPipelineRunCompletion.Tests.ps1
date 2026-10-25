BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Wait-GerberAdoPipelineRunCompletion' {
    BeforeEach {
        $script:selectedEnvironmentRequest = [pscustomobject]@{
            Configuration = [pscustomobject]@{}
            Pat = 'pat'
            BuildId = 72513
            SelectedEnvironmentName = 'PreProd'
            TimeoutSeconds = 1
            PollIntervalSeconds = 0
        }
    }

    It '<Name>' -TestCases @(
        @{
            Name                = 'returns when the run finishes successfully'
            Result              = 'succeeded'
            ExpectedBuildId     = 72513
            ExpectedErrorLike   = $null
        }
        @{
            Name                = 'throws when the run completes with a failure result'
            Result              = 'failed'
            ExpectedBuildId     = $null
            ExpectedErrorLike   = "*finish with result 'failed'*"
        }
    ) {
        param(
            [string]$Result,
            [int]$ExpectedBuildId,
            [string]$ExpectedErrorLike
        )

        Mock Get-GerberAdoPipelineRun {
            [pscustomobject]@{
                BuildId     = 72513
                BuildNumber = '20260607.2'
                Status      = 'completed'
                Result      = $Result
                RunUrl      = 'https://ado/_build/results?buildId=72513'
            }
        }

        $request = [pscustomobject]@{
            Configuration       = [pscustomobject]@{}
            Pat                 = 'pat'
            BuildId             = 72513
            TimeoutSeconds      = 1
            PollIntervalSeconds = 0
        }

        if ([string]::IsNullOrWhiteSpace($ExpectedErrorLike)) {
            $result = Wait-GerberAdoPipelineRunCompletion -RunWaitRequest $request
            $result.BuildId | Should -Be $ExpectedBuildId
            return
        }

        {
            Wait-GerberAdoPipelineRunCompletion -RunWaitRequest $request
        } |
            Should -Throw $ExpectedErrorLike
    }

    It 'throws when the run does not finish before the timeout expires' {
        $script:getDateIndex = 0
        Mock Get-Date {
            @(
                [datetime]'2026-06-07T12:00:00Z'
                [datetime]'2026-06-07T12:00:00Z'
                [datetime]'2026-06-07T12:00:02Z'
            )[$script:getDateIndex++]
        }
        Mock Get-GerberAdoPipelineRun {
            [pscustomobject]@{
                BuildId     = 72513
                BuildNumber = '20260607.2'
                Status      = 'inProgress'
                Result      = ''
            }
        }
        Mock Start-Sleep {}

        {
            Wait-GerberAdoPipelineRunCompletion -RunWaitRequest ([pscustomobject]@{
                    Configuration       = [pscustomobject]@{}
                    Pat                 = 'pat'
                    BuildId             = 72513
                    TimeoutSeconds      = 1
                    PollIntervalSeconds = 0
                })
        } |
            Should -Throw "*timed out while waiting*"

        Should -Invoke Start-Sleep -Times 1
    }

    It '<Name>' -TestCases @(
        @{
            Name = 'returns when the selected environment has finished and the run is waiting on another environment'
            Run = @{
                BuildId               = 72513
                BuildNumber           = '20260607.2'
                Status                = 'inProgress'
                Result                = ''
                EnvironmentName       = 'Prod'
                ApprovalEnvironmentMap = @{ 'approval-1' = 'Prod' }
                RunUrl                = 'https://ado/_build/results?buildId=72513'
            }
        }
        @{
            Name = 'returns when only a later pending approval remains even if the historical approval map still contains the selected environment'
            Run = @{
                BuildId                          = 72513
                BuildNumber                      = '20260607.2'
                Status                           = 'inProgress'
                Result                           = ''
                EnvironmentName                  = 'PreProd'
                ApprovalEnvironmentMap           = @{ 'approval-preprod' = 'PreProd'; 'approval-prod' = 'Prod' }
                PendingApprovalEnvironmentNameList = @('Prod')
                RunUrl                           = 'https://ado/_build/results?buildId=72513'
            }
        }
    ) {
        param($Run)

        $script:selectedEnvironmentRun = [pscustomobject]$Run
        Mock Get-GerberAdoPipelineRun { $script:selectedEnvironmentRun }
        Mock Start-Sleep {}

        $result = Wait-GerberAdoPipelineRunCompletion -RunWaitRequest $selectedEnvironmentRequest

        $result.BuildId | Should -Be 72513
        Should -Invoke Start-Sleep -Times 0
    }
}

Describe 'Wait-GerberAdoPipelineRunCompletion helpers' {
    It 'uses the default timeout and poll interval when overrides are omitted' {
        (Get-GerberAdoPipelineRunWaitOptionValue `
            -RunWaitRequest ([pscustomobject]@{}) `
            -PropertyName 'TimeoutSeconds' `
            -DefaultValue 1800) | Should -Be 1800
        (Get-GerberAdoPipelineRunWaitOptionValue `
            -RunWaitRequest ([pscustomobject]@{}) `
            -PropertyName 'PollIntervalSeconds' `
            -DefaultValue 5) | Should -Be 5
    }

    It 'loads a pipeline run through the shared rest request and conversion helpers' {
        $configuration = [pscustomobject]@{
            CollectionUri          = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName            = 'ExampleProject'
            CredentialIdentifier = 'gerber:ado:example:pat'
        }
        Mock Invoke-GerberAdoRestRequest {
            [pscustomobject]@{
                id         = 72513
                definition = [pscustomobject]@{
                    id = 313
                }
            }
        }
        $originalScriptBlock = (Get-Command ConvertTo-GerberAdoPipelineRunItem -CommandType Function).ScriptBlock
        Set-Item -Path function:global:ConvertTo-GerberAdoPipelineRunItem -Value {
            param(
                [object]$Build,
                [pscustomobject]$RunListRequest,
                [pscustomobject]$ResolutionContext
            )

            $null = $ResolutionContext
            [pscustomobject]@{
                BuildId      = $Build.id
                DefinitionId = $RunListRequest.DefinitionId
                IncludeApprovalEnvironmentMap = $RunListRequest.IncludeApprovalEnvironmentMap
            }
        }

        try {
            $result = Get-GerberAdoPipelineRun -Configuration $configuration -Pat 'pat' -BuildId 72513
        } finally {
            Set-Item -Path function:global:ConvertTo-GerberAdoPipelineRunItem -Value $originalScriptBlock
        }

        $result.BuildId | Should -Be 72513
        $result.DefinitionId | Should -Be 313
        $result.IncludeApprovalEnvironmentMap | Should -BeFalse
        (Get-GerberAdoPipelineRunUri -Configuration $configuration -BuildId 72513).AbsoluteUri |
            Should -Be 'https://ado.example.test/ExampleProject/ExampleProject/_apis/build/builds/72513?api-version=7.1'
    }

    It 'loads approval-environment maps when waiting for a selected environment' {
        $configuration = [pscustomobject]@{
            CollectionUri          = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName            = 'ExampleProject'
            CredentialIdentifier = 'gerber:ado:example:pat'
        }
        Mock Invoke-GerberAdoRestRequest {
            [pscustomobject]@{
                id         = 72513
                definition = [pscustomobject]@{
                    id = 313
                }
            }
        }
        $originalScriptBlock = (Get-Command ConvertTo-GerberAdoPipelineRunItem -CommandType Function).ScriptBlock
        Set-Item -Path function:global:ConvertTo-GerberAdoPipelineRunItem -Value {
            param(
                [object]$Build,
                [pscustomobject]$RunListRequest,
                [pscustomobject]$ResolutionContext
            )

            $null = $Build
            $null = $ResolutionContext
            [pscustomobject]@{
                IncludeApprovalEnvironmentMap = $RunListRequest.IncludeApprovalEnvironmentMap
            }
        }

        try {
            $result = Get-GerberAdoPipelineRun `
                -Configuration $configuration `
                -Pat 'pat' `
                -BuildId 72513 `
                -IncludeApprovalEnvironmentMap $true
        } finally {
            Set-Item -Path function:global:ConvertTo-GerberAdoPipelineRunItem -Value $originalScriptBlock
        }

        $result.IncludeApprovalEnvironmentMap | Should -BeTrue
    }

    It 'returns safe default definition ids for null and incomplete build metadata' {
        (Get-GerberAdoPipelineRunDefinitionId -Build $null) | Should -Be 0
        (Get-GerberAdoPipelineRunDefinitionId -Build @{ definition = @{ id = 314 } }) | Should -Be 314
        (Get-GerberAdoPipelineRunDefinitionId -Build ([pscustomobject]@{})) | Should -Be 0
    }

    It 'matches selected environment names case-insensitively across candidate lists' {
        (Test-GerberAdoPipelineRunEnvironmentNameMatch -CandidateList @('Prod', 'PreProd') -SelectedEnvironmentName 'preprod') | Should -BeTrue
        (Test-GerberAdoPipelineRunEnvironmentNameMatch -CandidateList @('Prod') -SelectedEnvironmentName 'PreProd') | Should -BeFalse
    }
}
