BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoPipelineRunList' {
    BeforeEach {
        $script:configuration = [pscustomobject]@{
            CollectionUri          = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName            = 'ExampleProject'
            CredentialIdentifier = 'gerber:ado:example:pat'
        }
        $script:buildPayload = [pscustomobject]@{
            id = 72513
            buildNumber = '20260607.2'
            environmentName = ''
            sourceBranch = 'refs/heads/main'
            status = 'notStarted'
            result = ''
            queueTime = '2026-06-07T12:20:06Z'
            finishTime = ''
            definition = [pscustomobject]@{ id = 313; name = 'Deploy Solr Core' }
        }
        Mock Invoke-GerberAdoRestRequest {
            [pscustomobject]@{ value = @($script:buildPayload) }
        }
    }

    It 'uses the build environment name when Azure DevOps exposes it directly' {
        $script:buildPayload.environmentName = 'PREPROD'
        $script:buildPayload.status = 'completed'
        $script:buildPayload.result = 'succeeded'
        $script:buildPayload.finishTime = '2026-06-07T12:22:06Z'
        Mock Get-GerberAdoPipelineRunTimeline {}
        Mock Get-GerberAdoBuildRunUrl { 'https://ado/_build/results?buildId=72513' }

        $result = @(Get-GerberAdoPipelineRunList -RunListRequest ([pscustomobject]@{
                    Configuration = $configuration
                    Pat           = 'pat'
                    DefinitionId  = 313
                    BranchName    = 'main'
                }))

        $result[0].BuildId | Should -Be 72513
        $result[0].EnvironmentName | Should -Be 'PreProd'
        Should -Invoke Get-GerberAdoPipelineRunTimeline -Times 0
    }

    It 'falls back to the timeline stage name when the build payload omits the environment' {
        $script:buildPayload.id = 72221
        $script:buildPayload.buildNumber = '20260607.5'
        $script:buildPayload.definition = [pscustomobject]@{ id = 101; name = 'SampleClient' }
        Mock Get-GerberAdoPipelineRunTimeline {
            @(
                [pscustomobject]@{ Id = 'stage-1'; ParentId = ''; Type = 'Stage'; Name = 'Deploy to Prod'; Identifier = 'Deploy_Prod' }
                [pscustomobject]@{ Id = 'checkpoint-1'; ParentId = 'stage-1'; Type = 'Checkpoint'; Name = 'Checkpoint'; Identifier = 'Checkpoint' }
                [pscustomobject]@{ Id = 'approval-1'; ParentId = 'checkpoint-1'; Type = 'Checkpoint.Approval'; Name = 'Review'; Identifier = 'Checkpoint.Approval' }
            )
        }
        Mock Get-GerberAdoBuildRunUrl { 'https://ado/_build/results?buildId=72221' }

        $result = @(Get-GerberAdoPipelineRunList -RunListRequest ([pscustomobject]@{
                    Configuration = $configuration
                    Pat           = 'pat'
                    DefinitionId  = 101
                    BranchName    = 'main'
                    IncludeApprovalEnvironmentMap = $true
                }))

        $result[0].EnvironmentName | Should -Be 'Prod'
        $result[0].ApprovalEnvironmentMap['approval-1'] | Should -Be 'Prod'
        $result[0].PendingApprovalEnvironmentNameList | Should -Be @('Prod')
        Should -Invoke Get-GerberAdoPipelineRunTimeline -Times 1
        Should -Invoke Invoke-GerberAdoRestRequest -Times 1
    }

    It 'falls back to the build template environment when deployment jobs only expose __default stage names' {
        Mock Get-GerberAdoPipelineRunTimeline {
            @(
                [pscustomobject]@{ Id = 'stage-1'; ParentId = ''; Type = 'Stage'; Name = '__default'; Identifier = '__default' }
                [pscustomobject]@{ Id = 'checkpoint-1'; ParentId = 'stage-1'; Type = 'Checkpoint'; Name = 'Checkpoint'; Identifier = 'Checkpoint' }
                [pscustomobject]@{ Id = 'approval-1'; ParentId = 'checkpoint-1'; Type = 'Checkpoint.Approval'; Name = 'Review'; Identifier = 'Checkpoint.Approval' }
            )
        }
        Mock Get-GerberAdoPipelineRunBuildResponse {
            [pscustomobject]@{
                templateParameters = [pscustomobject]@{
                    environmentName = 'PREPROD'
                }
            }
        }
        Mock Get-GerberAdoBuildRunUrl { 'https://ado/_build/results?buildId=72513' }

        $result = @(Get-GerberAdoPipelineRunList -RunListRequest ([pscustomobject]@{
                    Configuration = $configuration
                    Pat           = 'pat'
                    DefinitionId  = 313
                    BranchName    = 'main'
                    IncludeApprovalEnvironmentMap = $true
                }))

        $result[0].EnvironmentName | Should -Be 'PreProd'
        $result[0].ApprovalEnvironmentMap['approval-1'] | Should -Be 'PreProd'
        $result[0].PendingApprovalEnvironmentNameList | Should -Be @('PreProd')
        Should -Invoke Get-GerberAdoPipelineRunTimeline -Times 1
        Should -Invoke Get-GerberAdoPipelineRunBuildResponse -Times 1
    }

    It 'keeps approval environments distinct when one run contains more than one approval stage' {
        $script:buildPayload.id = 72221
        $script:buildPayload.buildNumber = '20260607.5'
        $script:buildPayload.definition = [pscustomobject]@{ id = 365; name = 'SampleClient' }
        Mock Get-GerberAdoPipelineRunTimeline {
            @(
                [pscustomobject]@{ Id = 'stage-prod'; ParentId = ''; Type = 'Stage'; Name = 'Deploy to Prod'; Identifier = 'Deploy_Prod' }
                [pscustomobject]@{ Id = 'checkpoint-prod'; ParentId = 'stage-prod'; Type = 'Checkpoint'; Name = 'Checkpoint'; Identifier = 'Checkpoint' }
                [pscustomobject]@{ Id = 'approval-prod'; ParentId = 'checkpoint-prod'; Type = 'Checkpoint.Approval'; Name = 'Checkpoint.Approval'; Identifier = 'approval-prod' }
                [pscustomobject]@{ Id = 'stage-preprod'; ParentId = ''; Type = 'Stage'; Name = 'Deploy to PreProd'; Identifier = 'Deploy_PreProd' }
                [pscustomobject]@{ Id = 'checkpoint-preprod'; ParentId = 'stage-preprod'; Type = 'Checkpoint'; Name = 'Checkpoint'; Identifier = 'Checkpoint' }
                [pscustomobject]@{ Id = 'approval-preprod'; ParentId = 'checkpoint-preprod'; Type = 'Checkpoint.Approval'; Name = 'Checkpoint.Approval'; Identifier = 'approval-preprod' }
            )
        }
        Mock Get-GerberAdoPipelineRunBuildResponse { [pscustomobject]@{} }
        Mock Get-GerberAdoBuildRunUrl { 'https://ado/_build/results?buildId=72221' }

        $result = @(Get-GerberAdoPipelineRunList -RunListRequest ([pscustomobject]@{
                    Configuration = $configuration
                    Pat           = 'pat'
                    DefinitionId  = 365
                    BranchName    = 'main'
                    IncludeApprovalEnvironmentMap = $true
                }))

        $result[0].ApprovalEnvironmentMap['approval-preprod'] | Should -Be 'PreProd'
        $result[0].ApprovalEnvironmentMap['approval-prod'] | Should -Be 'Prod'
        $result[0].PendingApprovalEnvironmentNameList | Should -Be @('Prod', 'PreProd')
        $result[0].EnvironmentName | Should -BeNullOrEmpty
    }

    It 'uses the template environment when parallel approvals live under generic stage names' {
        $script:buildPayload.id = 73626
        $script:buildPayload.buildNumber = '20260618.4'
        $script:buildPayload.status = 'inProgress'
        $script:buildPayload.queueTime = '2026-06-18T11:00:00Z'
        $script:buildPayload.definition = [pscustomobject]@{ id = 282; name = 'Sample_Inspection' }
        Mock Get-GerberAdoPipelineRunTimeline {
            @(
                [pscustomobject]@{ Id = 'stage-web'; ParentId = ''; Type = 'Stage'; Name = 'Deploy to web server'; Identifier = 'Deploy_WEB'; State = 'pending' }
                [pscustomobject]@{ Id = 'checkpoint-web'; ParentId = 'stage-web'; Type = 'Checkpoint'; Name = 'Checkpoint'; Identifier = 'Checkpoint'; State = 'inProgress' }
                [pscustomobject]@{ Id = 'approval-web'; ParentId = 'checkpoint-web'; Type = 'Checkpoint.Approval'; Name = 'Checkpoint.Approval'; Identifier = 'approval-web'; State = 'inProgress' }
                [pscustomobject]@{ Id = 'stage-app'; ParentId = ''; Type = 'Stage'; Name = 'Deploy to app server'; Identifier = 'Deploy_APP'; State = 'completed' }
                [pscustomobject]@{ Id = 'checkpoint-app'; ParentId = 'stage-app'; Type = 'Checkpoint'; Name = 'Checkpoint'; Identifier = 'Checkpoint'; State = 'completed' }
                [pscustomobject]@{ Id = 'approval-app'; ParentId = 'checkpoint-app'; Type = 'Checkpoint.Approval'; Name = 'Checkpoint.Approval'; Identifier = 'approval-app'; State = 'completed' }
            )
        }
        Mock Get-GerberAdoPipelineRunBuildResponse {
            [pscustomobject]@{
                templateParameters = [pscustomobject]@{
                    environment = 'PreProd'
                }
            }
        }
        Mock Get-GerberAdoBuildRunUrl { 'https://ado/_build/results?buildId=73626' }

        $result = @(Get-GerberAdoPipelineRunList -RunListRequest ([pscustomobject]@{
                    Configuration = $configuration
                    Pat           = 'pat'
                    DefinitionId  = 282
                    BranchName    = 'main'
                    IncludeApprovalEnvironmentMap = $true
                }))

        $result[0].EnvironmentName | Should -Be 'PreProd'
        $result[0].ApprovalEnvironmentMap['approval-web'] | Should -Be 'PreProd'
        $result[0].ApprovalEnvironmentMap['approval-app'] | Should -Be 'PreProd'
        $result[0].PendingApprovalEnvironmentNameList | Should -Be @('PreProd')
    }

    It 'prefers the active stage environment when a run has already moved past an earlier approval stage' {
        $script:buildPayload.id = 72976
        $script:buildPayload.buildNumber = '20260611.3'
        $script:buildPayload.status = 'inProgress'
        $script:buildPayload.queueTime = '2026-06-11T12:20:06Z'
        $script:buildPayload.definition = [pscustomobject]@{ id = 365; name = 'Sample Application' }
        Mock Get-GerberAdoPipelineRunTimeline {
            @(
                [pscustomobject]@{ Id = 'stage-preprod'; ParentId = ''; Type = 'Stage'; Name = 'Deploy to PreProd'; State = 'completed'; Result = 'succeeded' }
                [pscustomobject]@{ Id = 'checkpoint-preprod'; ParentId = 'stage-preprod'; Type = 'Checkpoint'; Name = 'Checkpoint' }
                [pscustomobject]@{ Id = 'approval-preprod'; ParentId = 'checkpoint-preprod'; Type = 'Checkpoint.Approval'; Name = 'Checkpoint.Approval'; State = 'completed' }
                [pscustomobject]@{ Id = 'stage-prod'; ParentId = ''; Type = 'Stage'; Name = 'Deploy to Prod'; State = 'inProgress' }
                [pscustomobject]@{ Id = 'checkpoint-prod'; ParentId = 'stage-prod'; Type = 'Checkpoint'; Name = 'Checkpoint' }
                [pscustomobject]@{ Id = 'approval-prod'; ParentId = 'checkpoint-prod'; Type = 'Checkpoint.Approval'; Name = 'Checkpoint.Approval'; State = 'completed' }
            )
        }
        Mock Get-GerberAdoBuildRunUrl { 'https://ado/_build/results?buildId=72976' }

        $result = @(Get-GerberAdoPipelineRunList -RunListRequest ([pscustomobject]@{
                    Configuration = $configuration
                    Pat           = 'pat'
                    DefinitionId  = 365
                    BranchName    = 'main'
                    IncludeApprovalEnvironmentMap = $true
                }))

        $result[0].EnvironmentName | Should -Be 'Prod'
        $result[0].PendingApprovalEnvironmentNameList | Should -Be @()
    }
}

Describe 'Get-GerberAdoPipelineRunListUri' {
    It 'builds the build runs API URI' {
        $configuration = [pscustomobject]@{
            CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName   = 'ExampleProject'
        }

        $uri = (Get-GerberAdoPipelineRunListUri -Configuration $configuration -DefinitionId 313 -BranchName 'main' -Top 25).AbsoluteUri

        $uri | Should -Match '^https://ado\.example\.test/ExampleProject/ExampleProject/_apis/build/builds\?'
        $uri | Should -Match 'api-version=7.1'
        $uri | Should -Match 'definitions=313'
        $uri | Should -Match 'branchName=refs%2Fheads%2Fmain'
        $uri | Should -Match 'queryOrder=queueTimeDescending'
        $uri | Should -Match '%24top=25'
    }
}

Describe 'Get-GerberAdoPipelineRunList helpers' {
    It 'uses the requested top value and include-approval flag when supplied' {
        (Get-GerberAdoPipelineRunListTop -RunListRequest ([pscustomobject]@{ Top = 25 })) | Should -Be 25
        (Test-GerberAdoPipelineRunIncludeApprovalEnvironmentMap -RunListRequest ([pscustomobject]@{ IncludeApprovalEnvironmentMap = $true })) | Should -BeTrue
        (Test-GerberAdoPipelineRunIncludeApprovalEnvironmentMap -RunListRequest ([pscustomobject]@{})) | Should -BeFalse
    }

    It 'falls back to the run environment when every approval map entry is unresolved' {
        $resolvedMap = Get-GerberAdoPipelineRunEffectiveApprovalEnvironmentMap `
            -ApprovalEnvironmentMap @{ 'approval-1' = '' } `
            -EnvironmentName 'PreProd'
        $resolvedMap['approval-1'] | Should -Be 'PreProd'

        $resolvedMultipleMap = Get-GerberAdoPipelineRunEffectiveApprovalEnvironmentMap `
            -ApprovalEnvironmentMap @{ 'approval-1' = ''; 'approval-2' = '' } `
            -EnvironmentName 'PreProd'
        $resolvedMultipleMap['approval-1'] | Should -Be 'PreProd'
        $resolvedMultipleMap['approval-2'] | Should -Be 'PreProd'

        $unchangedMixedMap = Get-GerberAdoPipelineRunEffectiveApprovalEnvironmentMap `
            -ApprovalEnvironmentMap @{ 'approval-1' = 'Prod'; 'approval-2' = '' } `
            -EnvironmentName 'PreProd'
        $unchangedMixedMap['approval-1'] | Should -Be 'Prod'
        $unchangedMixedMap['approval-2'] | Should -Be ''

        $blankFallbackMap = Get-GerberAdoPipelineRunEffectiveApprovalEnvironmentMap `
            -ApprovalEnvironmentMap @{ 'approval-1' = '' } `
            -EnvironmentName ''
        $blankFallbackMap['approval-1'] | Should -Be ''
    }

    It 'returns an empty timeline report when no timeline records are available' {
        Mock Get-GerberAdoPipelineRunTimelineRecordListCached { @() }

        $report = Get-GerberAdoPipelineRunTimelineEnvironmentReportCore `
            -BuildId 1 `
            -ResolutionContext ([pscustomobject]@{
                TimelineCache = @{}
                Configuration = [pscustomobject]@{}
                Pat = 'pat'
            })

        $report.RunEnvironmentName | Should -Be ''
        $report.ApprovalEnvironmentMap.Count | Should -Be 0
        $report.PendingApprovalEnvironmentNameList.Count | Should -Be 0
    }

    It 'tracks only non-completed approval environments as pending' {
        $pendingEnvironmentNameList = @(Get-GerberAdoPipelineRunPendingApprovalTimelineEnvironmentNameList `
                -TimelineRecordList @(
                    [pscustomobject]@{ Id = 'stage-preprod'; ParentId = ''; Type = 'Stage'; Name = 'Deploy to PreProd' }
                    [pscustomobject]@{ Id = 'checkpoint-preprod'; ParentId = 'stage-preprod'; Type = 'Checkpoint'; Name = 'Checkpoint' }
                    [pscustomobject]@{ Id = 'approval-preprod'; ParentId = 'checkpoint-preprod'; Type = 'Checkpoint.Approval'; Name = 'Checkpoint.Approval'; State = 'completed' }
                    [pscustomobject]@{ Id = 'stage-prod'; ParentId = ''; Type = 'Stage'; Name = 'Deploy to Prod' }
                    [pscustomobject]@{ Id = 'checkpoint-prod'; ParentId = 'stage-prod'; Type = 'Checkpoint'; Name = 'Checkpoint' }
                    [pscustomobject]@{ Id = 'approval-prod'; ParentId = 'checkpoint-prod'; Type = 'Checkpoint.Approval'; Name = 'Checkpoint.Approval'; State = 'pending' }
                ) `
                -RecordMap @{
                    'stage-preprod' = [pscustomobject]@{ Id = 'stage-preprod'; ParentId = ''; Type = 'Stage'; Name = 'Deploy to PreProd' }
                    'checkpoint-preprod' = [pscustomobject]@{ Id = 'checkpoint-preprod'; ParentId = 'stage-preprod'; Type = 'Checkpoint'; Name = 'Checkpoint' }
                    'approval-preprod' = [pscustomobject]@{ Id = 'approval-preprod'; ParentId = 'checkpoint-preprod'; Type = 'Checkpoint.Approval'; Name = 'Checkpoint.Approval'; State = 'completed' }
                    'stage-prod' = [pscustomobject]@{ Id = 'stage-prod'; ParentId = ''; Type = 'Stage'; Name = 'Deploy to Prod' }
                    'checkpoint-prod' = [pscustomobject]@{ Id = 'checkpoint-prod'; ParentId = 'stage-prod'; Type = 'Checkpoint'; Name = 'Checkpoint' }
                    'approval-prod' = [pscustomobject]@{ Id = 'approval-prod'; ParentId = 'checkpoint-prod'; Type = 'Checkpoint.Approval'; Name = 'Checkpoint.Approval'; State = 'pending' }
                })

        $pendingEnvironmentNameList | Should -Be @('Prod')
        (Test-GerberAdoPipelineRunPendingApprovalTimelineRecord -Record ([pscustomobject]@{ State = 'completed' })) | Should -BeFalse
        (Test-GerberAdoPipelineRunPendingApprovalTimelineRecord -Record ([pscustomobject]@{ State = 'approved' })) | Should -BeFalse
        (Test-GerberAdoPipelineRunPendingApprovalTimelineRecord -Record ([pscustomobject]@{ State = 'pending' })) | Should -BeTrue
        (Test-GerberAdoPipelineRunPendingApprovalTimelineRecord -Record ([pscustomobject]@{ Result = 'succeeded' })) | Should -BeFalse
        (Test-GerberAdoPipelineRunPendingApprovalTimelineRecord -Record ([pscustomobject]@{})) | Should -BeTrue
        (Test-GerberAdoPipelineRunPendingApprovalTimelineValue -Value 'inProgress') | Should -BeTrue
    }

    It 'falls back to a single effective approval environment when no pending timeline environment can be resolved' {
        @(Get-GerberAdoPipelineRunEffectivePendingApprovalEnvironmentNameList `
                -PendingApprovalEnvironmentNameList @() `
                -ApprovalEnvironmentMap @{ 'approval-1' = 'PreProd' }) | Should -Be @('PreProd')
        @(Get-GerberAdoPipelineRunEffectivePendingApprovalEnvironmentNameList `
                -PendingApprovalEnvironmentNameList @() `
                -ApprovalEnvironmentMap @{ 'approval-1' = 'PreProd'; 'approval-2' = 'PreProd' }) | Should -Be @('PreProd')
        @(Get-GerberAdoPipelineRunEffectivePendingApprovalEnvironmentNameList `
                -PendingApprovalEnvironmentNameList @() `
                -ApprovalEnvironmentMap @{ 'approval-1' = 'PreProd'; 'approval-2' = 'Prod' }) | Should -Be @()
    }

    It 'normalizes environment text and returns empty ancestor or single-stage matches when unresolved' {
        (Resolve-GerberAdoPipelineRunNormalizedEnvironmentName -Candidate 'Deploy TC12') | Should -Be 'TC12'
        (Resolve-GerberAdoPipelineRunNormalizedEnvironmentName -Candidate 'Deploy to Prod') | Should -Be 'Prod'
        (Resolve-GerberAdoPipelineRunNormalizedEnvironmentName -Candidate '') | Should -Be ''
        (Get-GerberAdoPipelineRunComparableText -Text '') | Should -Be ''
        (Get-GerberAdoPipelineRunActiveStageEnvironmentName -TimelineRecordList @(
                [pscustomobject]@{ Type = 'Stage'; Name = 'Deploy to PreProd'; State = 'completed'; Result = 'succeeded' }
                [pscustomobject]@{ Type = 'Stage'; Name = 'Deploy to Prod'; State = 'inProgress' }
            )) | Should -Be 'Prod'
        (Get-GerberAdoPipelineRunSingleStageEnvironmentName -MatchList @('Prod')) | Should -Be 'Prod'
        (Get-GerberAdoPipelineRunSingleStageEnvironmentName -MatchList @('Prod', 'PreProd')) | Should -Be ''
        (Test-GerberAdoPipelineRunActiveTimelineRecord -Record ([pscustomobject]@{ State = 'inProgress' })) | Should -BeTrue
        (Test-GerberAdoPipelineRunActiveTimelineRecord -Record ([pscustomobject]@{ Result = 'succeeded' })) | Should -BeFalse
        (Get-GerberAdoPipelineRunAncestorEnvironmentName `
            -Record ([pscustomobject]@{ Name = 'Checkpoint'; ParentId = 'missing' }) `
            -RecordMap @{}) | Should -Be ''
        (Get-GerberAdoPipelineRunAncestorEnvironmentName `
            -Record ([pscustomobject]@{ Name = 'Checkpoint'; ParentId = 'stage-1' }) `
            -RecordMap @{ 'stage-1' = $null }) | Should -Be ''
    }

    It 'builds and caches build responses and handles missing build metadata safely' {
        $configuration = [pscustomobject]@{
            CollectionUri          = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName            = 'ExampleProject'
            CredentialIdentifier = 'gerber:ado:example:pat'
        }
        $resolutionContext = [pscustomobject]@{
            Configuration = $configuration
            Pat           = 'pat'
            BuildCache    = @{}
        }
        Mock Invoke-GerberAdoRestRequest { [pscustomobject]@{ id = 72221 } }

        $first = Get-GerberAdoPipelineRunBuildResponse -BuildId 72221 -ResolutionContext $resolutionContext
        $second = Get-GerberAdoPipelineRunBuildResponse -BuildId 72221 -ResolutionContext $resolutionContext

        $first.id | Should -Be 72221
        $second.id | Should -Be 72221
        (Get-GerberAdoPipelineRunBuildUri -Configuration $configuration -BuildId 72221).AbsoluteUri | Should -Be 'https://ado.example.test/ExampleProject/ExampleProject/_apis/build/builds/72221?api-version=7.1'
        (Get-GerberAdoPipelineRunDefinitionName -Build $null) | Should -Be ''
        (Get-GerberAdoPipelineRunDefinitionName -Build @{ definition = @{ name = 'SampleClient' } }) | Should -Be 'SampleClient'
        (Get-GerberAdoPipelineRunDefinitionName -Build ([pscustomobject]@{})) | Should -Be ''
        (Get-GerberAdoPipelineRunNestedPropertyValue -InputObject $null -PropertyPath @('definition', 'name')) | Should -Be ''
        (Get-GerberAdoPipelineRunNestedPropertyValue -InputObject @{ definition = @{ name = 'SampleClient' } } -PropertyPath @('definition', 'name')) | Should -Be 'SampleClient'
        (Get-GerberAdoPipelineRunNestedPropertyValue -InputObject ([pscustomobject]@{ definition = $null }) -PropertyPath @('definition')) | Should -Be ''
        (Get-GerberAdoPipelineRunObjectPropertyValue -InputObject $null -PropertyName 'id') | Should -Be $null
        (Get-GerberAdoPipelineRunObjectPropertyValue -InputObject @{ id = 1 } -PropertyName 'id') | Should -Be 1
        (Get-GerberAdoPipelineRunObjectPropertyValue -InputObject ([pscustomobject]@{}) -PropertyName 'id') | Should -Be $null
        Should -Invoke Invoke-GerberAdoRestRequest -Times 1
    }

    It 'resolves template and detail environment fallbacks' {
        Mock Get-GerberAdoPipelineRunTimelineEnvironmentName { '' }
        Mock Get-GerberAdoPipelineRunBuildResponse {
            [pscustomobject]@{
                environmentName = 'PREPROD'
                templateParameters = [pscustomobject]@{}
            }
        }

        $environmentName = Resolve-GerberAdoPipelineRunEnvironmentName `
            -Build ([pscustomobject]@{ templateParameters = [pscustomobject]@{ environmentName = 'PROD' } }) `
            -BuildId 72221 `
            -ResolutionContext ([pscustomobject]@{
                Configuration = [pscustomobject]@{}
                Pat = 'pat'
                BuildCache = @{}
            }) `
            -TimelineEnvironmentReport ([pscustomobject]@{
                RunEnvironmentName = ''
                ApprovalEnvironmentMap = @{}
            })
        $environmentName | Should -Be 'Prod'

        $templateAliasEnvironmentName = Resolve-GerberAdoPipelineRunEnvironmentName `
            -Build ([pscustomobject]@{ templateParameters = [pscustomobject]@{ environment = 'PREPROD' } }) `
            -BuildId 72220 `
            -ResolutionContext ([pscustomobject]@{
                Configuration = [pscustomobject]@{}
                Pat = 'pat'
                BuildCache = @{}
            }) `
            -TimelineEnvironmentReport ([pscustomobject]@{
                RunEnvironmentName = ''
                ApprovalEnvironmentMap = @{}
            })
        $templateAliasEnvironmentName | Should -Be 'PreProd'

        Mock Get-GerberAdoPipelineRunBuildResponse {
            [pscustomobject]@{
               environmentName     = 'PREPROD'
               templateParameters  = [pscustomobject]@{}
            }
        }

        $detailEnvironmentName = Resolve-GerberAdoPipelineRunEnvironmentName `
            -Build ([pscustomobject]@{ templateParameters = [pscustomobject]@{} }) `
            -BuildId 72222 `
            -ResolutionContext ([pscustomobject]@{
               Configuration = [pscustomobject]@{}
               Pat           = 'pat'
               BuildCache    = @{}
            }) `
            -TimelineEnvironmentReport ([pscustomobject]@{
               RunEnvironmentName      = ''
               ApprovalEnvironmentMap  = @{}
            })
        $detailEnvironmentName | Should -Be 'PreProd'
    }

    It 'loads the timeline environment report when none is supplied' {
        Mock Get-GerberAdoPipelineRunTimelineRecordListCached {
            @(
                [pscustomobject]@{ Id = 'stage-1'; ParentId = ''; Type = 'Stage'; Name = 'Deploy to PreProd'; Identifier = 'Deploy_PreProd' }
            )
        }

        (Get-GerberAdoPipelineRunTimelineEnvironmentName `
            -BuildId 72221 `
            -ResolutionContext ([pscustomobject]@{
                Configuration = [pscustomobject]@{}
                Pat = 'pat'
                TimelineCache = @{}
            }) `
            -TimelineEnvironmentReport $null) | Should -Be 'PreProd'
    }
}
