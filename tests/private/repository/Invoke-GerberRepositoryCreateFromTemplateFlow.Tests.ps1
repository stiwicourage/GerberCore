BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

function global:New-RepositoryCreateContext {
    param(
        [string]$RepositoryName = 'MyPkg',
        [pscustomobject]$Template = [pscustomobject]@{ Id = 'tpl'; Name = 'Template_NuGet'; DefaultBranch = 'refs/heads/main' },
        [pscustomobject]$Team = [pscustomobject]@{ Id = 'team1'; Name = 'TeamA' },
        [pscustomobject]$ProjectContext = [pscustomobject]@{
            ConfiguredProjectName = 'Project-A'
            Project = [pscustomobject]@{ Id = 'project-b-id'; Name = 'Project-B' }
        }
    )

    return [pscustomobject]@{
        Configuration = [pscustomobject]@{ ProjectName = $ProjectContext.ConfiguredProjectName; CredentialIdentifier = 'PAT' }
        Pat = 'test-pat'
        Project = $ProjectContext.Project
        RepositoryName = $RepositoryName
        Template = $Template
        Team = $Team
    }
}

function global:New-RepositoryCreateBuildValidationPolicy {
    param(
        [int]$Id = 1,
        [int]$BuildDefinitionId = 42,
        [string]$DisplayName = 'Template_NuGet (build and publish)'
    )

    return [pscustomobject]@{
        Id = $Id
        Type = [pscustomobject]@{ id = 'type-build' }
        Settings = [pscustomobject]@{
            buildDefinitionId = $BuildDefinitionId
            displayName = $DisplayName
            scope = @(@{ repositoryId = 'tpl'; refName = 'refs/heads/main'; matchKind = 'Exact' })
        }
    }
}

Describe 'Invoke-GerberRepositoryCreateFromTemplateFlow' {
    It 'calls Invoke-GerberRepositoryCreateFromTemplateIteration with ProjectSelection and TemplateSelection' {
        Mock Show-GerberRepositoryCreateFromTemplateHeader {}
        Mock Invoke-GerberRepositoryCreateFromTemplateIteration { $true }

        Invoke-GerberRepositoryCreateFromTemplateFlow `
            -ProjectSelection ([pscustomobject]@{ Id = 'p1'; Name = 'Proj' }) `
            -TemplateSelection ([pscustomobject]@{ Id = '1'; Name = 'Template_NuGet' })

        Should -Invoke Invoke-GerberRepositoryCreateFromTemplateIteration -Times 1 `
            -ParameterFilter { $ProjectSelection.Name -eq 'Proj' -and $TemplateSelection.Name -eq 'Template_NuGet' }
    }

    It 'returns the result of Invoke-GerberRepositoryCreateFromTemplateIteration' {
        Mock Show-GerberRepositoryCreateFromTemplateHeader {}
        Mock Invoke-GerberRepositoryCreateFromTemplateIteration { $false }

        $result = Invoke-GerberRepositoryCreateFromTemplateFlow `
            -ProjectSelection ([pscustomobject]@{ Id = 'p1'; Name = 'Proj' }) `
            -TemplateSelection ([pscustomobject]@{ Id = '1'; Name = 'Template_NuGet' })

        $result | Should -BeFalse
    }
}

Describe 'Read-GerberRepositoryCreateRepositoryNameOrNull' {
    It 'returns the typed repository name when no exception is thrown' {
        Mock Read-GerberCommand { 'MyPackage' }

        $result = Read-GerberRepositoryCreateRepositoryNameOrNull

        $result | Should -Be 'MyPackage'
    }

    It 'returns null when Escape is pressed' {
        Mock Read-GerberCommand { throw (Get-GerberMenuEscapeException) }

        $result = Read-GerberRepositoryCreateRepositoryNameOrNull

        $result | Should -BeNull
    }
}

Describe 'Read-GerberRepositoryCreateTeamOrNull' {
    It 'returns selected team when no exception is thrown' {
        Mock Get-GerberAdoConfiguration { [pscustomobject]@{ CredentialIdentifier = 'PAT' } }
        Mock Resolve-GerberAdoPat { 'pat' }
        Mock Get-GerberAdoTeamList { @([pscustomobject]@{ Id = 't1'; Name = 'TeamA' }) }
        Mock Convert-GerberListToNumberedMenuItemList { @([pscustomobject]@{ Number = 1; Label = 'TeamA'; Value = 'TeamA'; PreviewText = '' }) }
        Mock Read-GerberNumberedMenuPrompt { 'TeamA' }

        $result = Read-GerberRepositoryCreateTeamOrNull -ProjectSelection ([pscustomobject]@{ Id = 'p1' })

        $result.Name | Should -Be 'TeamA'
    }

    It 'returns null when Escape is pressed' {
        Mock Get-GerberAdoConfiguration { [pscustomobject]@{ CredentialIdentifier = 'PAT' } }
        Mock Resolve-GerberAdoPat { 'pat' }
        Mock Get-GerberAdoTeamList { @() }
        Mock Convert-GerberListToNumberedMenuItemList { @() }
        Mock Read-GerberNumberedMenuPrompt { throw (Get-GerberMenuEscapeException) }

        $result = Read-GerberRepositoryCreateTeamOrNull -ProjectSelection ([pscustomobject]@{ Id = 'p1' })

        $result | Should -BeNull
    }
}

Describe 'Build-GerberRepositoryCreateContext' {
    It 'returns context with all required fields' {
        Mock Get-GerberAdoConfiguration { [pscustomobject]@{ CredentialIdentifier = 'PAT' } }
        Mock Resolve-GerberAdoPat { 'test-pat' }

        $context = Build-GerberRepositoryCreateContext `
            -ProjectSelection ([pscustomobject]@{ Id = 'p1'; Name = 'Proj' }) `
            -TemplateSelection ([pscustomobject]@{ Id = 't1'; Name = 'Template_NuGet' }) `
            -RepositoryName 'MyPkg' `
            -TeamSelection ([pscustomobject]@{ Id = 'tm1'; Name = 'TeamA' })

        $context.RepositoryName | Should -Be 'MyPkg'
        $context.Pat | Should -Be 'test-pat'
        $context.Project.Name | Should -Be 'Proj'
        $context.Template.Name | Should -Be 'Template_NuGet'
        $context.Team.Name | Should -Be 'TeamA'
    }
}

Describe 'Show-GerberRepositoryCreatePreview' {
    It 'displays repository details' {
        Mock Clear-Host {}
        Mock Write-GerberScreenLine {}

        $context = [pscustomobject]@{
            RepositoryName = 'MyPkg'
            Template = [pscustomobject]@{ Name = 'Template_NuGet' }
            Team = [pscustomobject]@{ Name = 'TeamA' }
        }

        Show-GerberRepositoryCreatePreview -Context $context

        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -like '*MyPkg*' }
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -like '*Template_NuGet*' }
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -like '*TeamA*' }
    }
}

Describe 'Confirm-GerberRepositoryCreateApply' {
    It 'returns true when Apply is selected' {
        Mock Read-GerberConfirmationPrompt { $true }

        $result = Confirm-GerberRepositoryCreateApply

        $result | Should -BeTrue
    }

    It 'returns false when Cancel is selected' {
        Mock Read-GerberConfirmationPrompt { $false }

        $result = Confirm-GerberRepositoryCreateApply

        $result | Should -BeFalse
    }

    It 'returns false when Escape is pressed' {
        Mock Read-GerberConfirmationPrompt { throw (Get-GerberMenuEscapeException) }

        $result = Confirm-GerberRepositoryCreateApply

        $result | Should -BeFalse
    }
}

Describe 'Wait-GerberRepositoryCreateContinue' {
    It 'returns true when Enter is pressed' {
        Mock Wait-GerberContinue {}

        $result = Wait-GerberRepositoryCreateContinue

        $result | Should -BeTrue
    }

    It 'returns false when Escape is pressed' {
        Mock Wait-GerberContinue { throw (Get-GerberMenuEscapeException) }

        $result = Wait-GerberRepositoryCreateContinue

        $result | Should -BeFalse
    }
}

Describe 'Convert-GerberListToNumberedMenuItemList' {
    It 'uses DisplayProperty for Value when ValueProperty is not specified' {
        $items = @([pscustomobject]@{ Name = 'Alpha'; Code = 'A' })

        $result = @(Convert-GerberListToNumberedMenuItemList -ItemList $items -DisplayProperty 'Name')

        $result[0].Label | Should -Be 'Alpha'
        $result[0].Value | Should -Be 'Alpha'
    }

    It 'uses ValueProperty for Value when ValueProperty is specified' {
        $items = @([pscustomobject]@{ Name = 'Alpha'; Code = 'A' })

        $result = @(Convert-GerberListToNumberedMenuItemList -ItemList $items -DisplayProperty 'Name' -ValueProperty 'Code')

        $result[0].Label | Should -Be 'Alpha'
        $result[0].Value | Should -Be 'A'
    }

    It 'assigns sequential numbers starting at 1' {
        $items = @(
            [pscustomobject]@{ Name = 'First' }
            [pscustomobject]@{ Name = 'Second' }
        )

        $result = @(Convert-GerberListToNumberedMenuItemList -ItemList $items -DisplayProperty 'Name')

        $result[0].Number | Should -Be 1
        $result[1].Number | Should -Be 2
    }

    It 'returns empty array for empty input list' {
        $result = @(Convert-GerberListToNumberedMenuItemList -ItemList @() -DisplayProperty 'Name')

        $result.Count | Should -Be 0
    }
}

Describe 'New-GerberAdoPipelinesFromTemplate' {
    It 'processes template pipeline files for <Scenario>' -ForEach @(
        @{
            Scenario = 'multiple yaml files under pipelines/'
            FileTree = @(
                [pscustomobject]@{ path = '/pipelines/build.yml'; gitObjectType = 'blob'; content = '' }
                [pscustomobject]@{ path = '/pipelines/deploy.yaml'; gitObjectType = 'blob'; content = '' }
                [pscustomobject]@{ path = '/src/TestPkg.csproj'; gitObjectType = 'blob'; content = '' }
            )
            ExpectedCalls = 2
        }
        @{
            Scenario = 'non-yaml files and tree entries'
            FileTree = @(
                [pscustomobject]@{ path = '/pipelines'; gitObjectType = 'tree'; content = '' }
                [pscustomobject]@{ path = '/pipelines/build.yml'; gitObjectType = 'blob'; content = '' }
                [pscustomobject]@{ path = '/README.md'; gitObjectType = 'blob'; content = '' }
            )
            ExpectedCalls = 1
        }
    ) {
        Mock New-GerberAdoPipeline { [pscustomobject]@{ Success = $true; PipelineId = 99; YamlPath = '/pipelines/build.yml'; PipelineName = 'TestPkg (build)' } }

        $context = New-RepositoryCreateContext `
            -RepositoryName 'TestPkg' `
            -Template ([pscustomobject]@{ DefaultBranch = 'refs/heads/main' })

        $null = New-GerberAdoPipelinesFromTemplate -Context $context -RepoId 'r1' -FileTree $FileTree

        Should -Invoke New-GerberAdoPipeline -Times $ExpectedCalls
    }

    It 'returns success with no pipelines created when FileTree has no yml files' {
        Mock New-GerberAdoPipeline { [pscustomobject]@{ Success = $true; PipelineId = 99; YamlPath = '/pipelines/build.yml'; PipelineName = 'TestPkg (build)' } }

        $context = New-RepositoryCreateContext `
            -RepositoryName 'TestPkg' `
            -Template ([pscustomobject]@{ DefaultBranch = 'refs/heads/main' })
        $result = New-GerberAdoPipelinesFromTemplate -Context $context -RepoId 'r1' -FileTree @()

        $result.Success | Should -BeTrue
        Should -Invoke New-GerberAdoPipeline -Times 0
    }

    It 'returns failure with ErrorDetail when a pipeline creation fails' {
        Mock New-GerberAdoPipeline { [pscustomobject]@{ Success = $false; ErrorDetail = 'API error' } }

        $context = New-RepositoryCreateContext `
            -RepositoryName 'TestPkg' `
            -Template ([pscustomobject]@{ DefaultBranch = 'refs/heads/main' })
        $fileTree = @(
            [pscustomobject]@{ path = '/pipelines/build.yml'; gitObjectType = 'blob'; content = '' }
        )
        $result = New-GerberAdoPipelinesFromTemplate -Context $context -RepoId 'r1' -FileTree $fileTree

        $result.Success | Should -BeFalse
        $result.ErrorDetail | Should -Not -BeNullOrEmpty
    }

    It 'passes the original path with leading slash to New-GerberAdoPipeline' {
        $script:capturedYamlPath = $null
        Mock New-GerberAdoPipeline {
            $script:capturedYamlPath = $YamlPath
            [pscustomobject]@{ Success = $true; PipelineId = 99; YamlPath = '/pipelines/build.yml'; PipelineName = 'TestPkg (build)' }
        }

        $context = New-RepositoryCreateContext `
            -RepositoryName 'TestPkg' `
            -Template ([pscustomobject]@{ DefaultBranch = 'refs/heads/main' })
        $fileTree = @(
            [pscustomobject]@{ path = '/pipelines/build.yml'; gitObjectType = 'blob'; content = '' }
        )
        $null = New-GerberAdoPipelinesFromTemplate -Context $context -RepoId 'r1' -FileTree $fileTree

        $script:capturedYamlPath | Should -Be '/pipelines/build.yml'
    }

    It 'returns PipelineMap keyed by normalized YamlPath on success' {
        Mock New-GerberAdoPipeline {
            [pscustomobject]@{ Success = $true; PipelineId = 77; YamlPath = '/pipelines/build-and-publish.yml'; PipelineName = 'MyPkg (build and publish)' }
        }

        $context = New-RepositoryCreateContext `
            -RepositoryName 'MyPkg' `
            -Template ([pscustomobject]@{ DefaultBranch = 'refs/heads/main' })
        $fileTree = @(
            [pscustomobject]@{ path = '/pipelines/build-and-publish.yml'; gitObjectType = 'blob'; content = '' }
        )
        $result = New-GerberAdoPipelinesFromTemplate -Context $context -RepoId 'r1' -FileTree $fileTree

        $result.Success | Should -BeTrue
        $result.PipelineMap | Should -Not -BeNullOrEmpty
        $result.PipelineMap['/pipelines/build-and-publish.yml'].Id | Should -Be 77
        $result.PipelineMap['/pipelines/build-and-publish.yml'].Name | Should -Be 'MyPkg (build and publish)'
    }
}

Describe 'New-GerberAdoRepositoryBranchSet' {
    It 'fetches template branches and creates all non-default branches' {
        Mock Get-GerberAdoRepositoryBranchList {
            @('refs/heads/develop', 'refs/heads/release', 'refs/heads/main')
        }
        Mock New-GerberAdoRepositoryBranch { [pscustomobject]@{ Success = $true } }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{ ProjectName = 'TestProj'; CredentialIdentifier = 'PAT' }
            Pat = 'test-pat'
            Template = [pscustomobject]@{ Id = 't1'; DefaultBranch = 'refs/heads/main' }
        }
        $result = New-GerberAdoRepositoryBranchSet -Context $context -RepoId 'r1'

        $result.Success | Should -BeTrue
        Should -Invoke New-GerberAdoRepositoryBranch -Times 2
    }

    It 'skips the default branch when creating branches' {
        Mock Get-GerberAdoRepositoryBranchList {
            @('refs/heads/develop', 'refs/heads/main')
        }
        Mock New-GerberAdoRepositoryBranch { [pscustomobject]@{ Success = $true } }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{ ProjectName = 'TestProj'; CredentialIdentifier = 'PAT' }
            Pat = 'test-pat'
            Template = [pscustomobject]@{ Id = 't1'; DefaultBranch = 'refs/heads/main' }
        }
        $null = New-GerberAdoRepositoryBranchSet -Context $context -RepoId 'r1'

        Should -Invoke New-GerberAdoRepositoryBranch -Times 1 -ParameterFilter { $BranchRef -eq 'refs/heads/develop' }
        Should -Invoke New-GerberAdoRepositoryBranch -Times 0 -ParameterFilter { $BranchRef -eq 'refs/heads/main' }
    }

    It 'returns failure when an exception occurs' {
        Mock Get-GerberAdoRepositoryBranchList { throw [System.InvalidOperationException]::new('Error') }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{ ProjectName = 'TestProj'; CredentialIdentifier = 'PAT' }
            Pat = 'test-pat'
            Template = [pscustomobject]@{ Id = 't1'; DefaultBranch = 'refs/heads/main' }
        }
        $result = New-GerberAdoRepositoryBranchSet -Context $context -RepoId 'r1'

        $result.Success | Should -BeFalse
    }
}

Describe 'Set-GerberAdoRepositoryCreateDefaultBranch' {
    It 'calls Get-GerberAdoRepositoryPatchUri and Invoke-GerberAdoRestMutation and returns success' {
        Mock Get-GerberAdoRepositoryPatchUri { [uri]'https://example.test/repo/r1' }
        Mock Build-GerberAdoRepositoryDefaultBranchBody { '{"defaultBranch":"refs/heads/develop"}' }
        Mock Invoke-GerberAdoRestMutation {}

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'TestProj'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
            Template = [pscustomobject]@{ DefaultBranch = 'refs/heads/develop' }
        }
        $result = Set-GerberAdoRepositoryCreateDefaultBranch -Context $context -RepoId 'r1'

        $result.Success | Should -BeTrue
        Should -Invoke Get-GerberAdoRepositoryPatchUri -Times 1
        Should -Invoke Invoke-GerberAdoRestMutation -Times 1
    }

    It 'uses the selected project scope instead of the configured default project' {
        Mock Get-GerberAdoRepositoryPatchUri { [uri]'https://example.test/repo/r1' }
        Mock Build-GerberAdoRepositoryDefaultBranchBody { '{"defaultBranch":"refs/heads/develop"}' }
        Mock Invoke-GerberAdoRestMutation {}

        $context = New-RepositoryCreateContext -Template ([pscustomobject]@{ DefaultBranch = 'refs/heads/develop' })
        $null = Set-GerberAdoRepositoryCreateDefaultBranch -Context $context -RepoId 'r1'

        Should -Invoke Get-GerberAdoRepositoryPatchUri -Times 1 -ParameterFilter {
            $ProjectScope -eq 'project-b-id' -and $Configuration.ProjectName -eq 'Project-A'
        }
    }

    It 'returns failure when mutation throws' {
        Mock Get-GerberAdoRepositoryPatchUri { [uri]'https://example.test/repo/r1' }
        Mock Build-GerberAdoRepositoryDefaultBranchBody { '{}' }
        Mock Invoke-GerberAdoRestMutation { throw [System.InvalidOperationException]::new('Error') }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{
                ProjectName = 'TestProj'
                CredentialIdentifier = 'PAT'
            }
            Pat = 'test-pat'
            Template = [pscustomobject]@{ DefaultBranch = 'refs/heads/develop' }
        }
        $result = Set-GerberAdoRepositoryCreateDefaultBranch -Context $context -RepoId 'r1'

        $result.Success | Should -BeFalse
    }
}

Describe 'Copy-GerberAdoPoliciesFromTemplate' {
    It 'copies non-build-validation policies without remapping' {
        Mock Get-GerberAdoRepoPolicyList {
            @([pscustomobject]@{
                Id = 1
                Type = [pscustomobject]@{ id = 'type-abc' }
                Settings = [pscustomobject]@{ scope = @(@{ repositoryId = 'tpl'; refName = 'refs/heads/main'; matchKind = 'Exact' }) }
            })
        }
        Mock Get-GerberAdoRepositoryBranchList { @() }
        Mock New-GerberAdoPolicyConfiguration { [pscustomobject]@{ Success = $true } }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{ ProjectName = 'TestProj'; CredentialIdentifier = 'PAT' }
            Pat = 'test-pat'
            Template = [pscustomobject]@{ Id = 'tpl' }
            Team = [pscustomobject]@{ Id = 'team1' }
        }
        $result = Copy-GerberAdoPoliciesFromTemplate -Context $context -RepoId 'r1' -PipelineMap @{}

        $result.Success | Should -BeTrue
        Should -Invoke New-GerberAdoPolicyConfiguration -Times 1
    }

    It 'remaps build validation policy to new pipeline when match found in PipelineMap' {
        $script:capturedPolicy = $null
        Mock Get-GerberAdoRepoPolicyList {
            @([pscustomobject]@{
                Id = 2
                Type = [pscustomobject]@{ id = 'type-build' }
                Settings = [pscustomobject]@{
                    buildDefinitionId = 42
                    displayName = 'Template_NuGet (build and publish)'
                    scope = @(@{ repositoryId = 'tpl'; refName = 'refs/heads/main'; matchKind = 'Exact' })
                }
            })
        }
        Mock Get-GerberAdoPipelineDefinition {
            [pscustomobject]@{ Success = $true; YamlPath = '/pipelines/build-and-publish.yml' }
        }
        Mock Get-GerberAdoRepositoryBranchList { @() }
        Mock New-GerberAdoPolicyConfiguration {
            $script:capturedPolicy = $Policy
            [pscustomobject]@{ Success = $true }
        }

        $context = New-RepositoryCreateContext -RepositoryName 'MyPkg' -Template ([pscustomobject]@{ Id = 'tpl'; Name = 'Template_NuGet' })
        $pipelineMap = @{
            '/pipelines/build-and-publish.yml' = @{ Id = 99; Name = 'MyPkg (build and publish)' }
        }
        $result = Copy-GerberAdoPoliciesFromTemplate -Context $context -RepoId 'r1' -PipelineMap $pipelineMap

        $result.Success | Should -BeTrue
        Should -Invoke New-GerberAdoPolicyConfiguration -Times 1
        $script:capturedPolicy.Settings.buildDefinitionId | Should -Be 99
        $script:capturedPolicy.Settings.displayName | Should -Be 'MyPkg (build and publish)'
    }

    It 'skips build validation policy copy when <Scenario>' -ForEach @(
        @{
            Scenario = 'pipeline definition lookup fails'
            PipelineDefinition = [pscustomobject]@{ Success = $false; YamlPath = '' }
            PipelineMap = @{}
        }
        @{
            Scenario = 'the yaml path is not found in PipelineMap'
            PipelineDefinition = [pscustomobject]@{ Success = $true; YamlPath = '/pipelines/other.yml' }
            PipelineMap = @{ '/pipelines/build-and-publish.yml' = @{ Id = 99; Name = 'MyPkg (build and publish)' } }
        }
    ) {
        Mock Get-GerberAdoRepoPolicyList { @(New-RepositoryCreateBuildValidationPolicy -Id 3) }
        Mock Get-GerberAdoPipelineDefinition { $PipelineDefinition }
        Mock Get-GerberAdoRepositoryBranchList { @() }
        Mock New-GerberAdoPolicyConfiguration { [pscustomobject]@{ Success = $true } }

        $context = New-RepositoryCreateContext -Template ([pscustomobject]@{ Id = 'tpl' })
        $result = Copy-GerberAdoPoliciesFromTemplate -Context $context -RepoId 'r1' -PipelineMap $PipelineMap

        $result.Success | Should -BeTrue
        Should -Invoke New-GerberAdoPolicyConfiguration -Times 0
    }

    It 'skips required-reviewer policy from template copy loop' {
        Mock Get-GerberAdoRepoPolicyList {
            @([pscustomobject]@{
                Id = 5
                Type = [pscustomobject]@{ id = 'fd2167ab-b0be-447a-8ec8-39368250530e' }
                Settings = [pscustomobject]@{
                    requiredReviewerIds = @('team-old')
                    scope = @(@{ repositoryId = 'tpl'; refName = 'refs/heads/main'; matchKind = 'Exact' })
                }
            })
        }
        Mock Get-GerberAdoRepositoryBranchList { @() }
        Mock New-GerberAdoPolicyConfiguration { [pscustomobject]@{ Success = $true } }

        $context = New-RepositoryCreateContext -Template ([pscustomobject]@{ Id = 'tpl' })
        $result = Copy-GerberAdoPoliciesFromTemplate -Context $context -RepoId 'r1' -PipelineMap @{}

        $result.Success | Should -BeTrue
        Should -Invoke New-GerberAdoPolicyConfiguration -Times 0
    }

    It 'adds required-reviewer policy on every branch of the new repo' {
        Mock Get-GerberAdoRepoPolicyList { @() }
        Mock Get-GerberAdoRepositoryBranchList { @('refs/heads/develop', 'refs/heads/main') }
        Mock New-GerberAdoPolicyConfiguration { [pscustomobject]@{ Success = $true } }

        $context = New-RepositoryCreateContext -Template ([pscustomobject]@{ Id = 'tpl' })
        $result = Copy-GerberAdoPoliciesFromTemplate -Context $context -RepoId 'r1' -PipelineMap @{}

        $result.Success | Should -BeTrue
        Should -Invoke New-GerberAdoPolicyConfiguration -Times 2
    }

    It 'remaps build validation policies for <Scenario>' -ForEach @(
        @{
            Scenario = 'yaml paths that need a leading slash for lookup'
            Policy = New-RepositoryCreateBuildValidationPolicy -Id 6 -BuildDefinitionId 55
            PipelineDefinition = [pscustomobject]@{ Success = $true; YamlPath = 'pipelines/build-and-publish.yml' }
            RepositoryContext = (New-RepositoryCreateContext -RepositoryName 'MyPkg' -Template ([pscustomobject]@{ Id = 'tpl'; Name = 'Template_NuGet' }))
            PipelineMap = @{ '/pipelines/build-and-publish.yml' = @{ Id = 77; Name = 'MyPkg (build and publish)' } }
            ExpectedPipelineId = 77
            ExpectedDisplayName = 'MyPkg (build and publish)'
        }
        @{
            Scenario = 'legacy PackageName placeholders without a template name'
            Policy = New-RepositoryCreateBuildValidationPolicy -Id 7 -BuildDefinitionId 88 -DisplayName 'PackageName (build and publish)'
            PipelineDefinition = [pscustomobject]@{ Success = $true; YamlPath = '/pipelines/build-and-publish.yml' }
            RepositoryContext = (New-RepositoryCreateContext -RepositoryName 'MyPkg' -Template ([pscustomobject]@{ Id = 'tpl' }))
            PipelineMap = @{ '/pipelines/build-and-publish.yml' = @{ Id = 11; Name = 'MyPkg (build and publish)' } }
            ExpectedPipelineId = 11
            ExpectedDisplayName = 'MyPkg (build and publish)'
        }
    ) {
        $script:capturedPolicy = $null
        Mock Get-GerberAdoRepoPolicyList { @($Policy) }
        Mock Get-GerberAdoPipelineDefinition { $PipelineDefinition }
        Mock Get-GerberAdoRepositoryBranchList { @() }
        Mock New-GerberAdoPolicyConfiguration {
            $script:capturedPolicy = $Policy
            [pscustomobject]@{ Success = $true }
        }

        $result = Copy-GerberAdoPoliciesFromTemplate -Context $RepositoryContext -RepoId 'r1' -PipelineMap $PipelineMap

        $result.Success | Should -BeTrue
        Should -Invoke New-GerberAdoPolicyConfiguration -Times 1
        $script:capturedPolicy.Settings.buildDefinitionId | Should -Be $ExpectedPipelineId
        $script:capturedPolicy.Settings.displayName | Should -Be $ExpectedDisplayName
    }

    It 'returns failure when an exception is thrown during policy copy' {
        Mock Get-GerberAdoRepoPolicyList { throw [System.InvalidOperationException]::new('Policy list error') }

        $context = New-RepositoryCreateContext -Template ([pscustomobject]@{ Id = 'tpl' })
        $result = Copy-GerberAdoPoliciesFromTemplate -Context $context -RepoId 'r1' -PipelineMap @{}

        $result.Success | Should -BeFalse
        $result.ErrorDetail | Should -Be 'Policy list error'
    }
}

Describe 'Invoke-GerberRepositoryCreateApplyWithProgress' {
    It 'passes branch name derived from Template.DefaultBranch to Get-GerberAdoRepositoryItemTree' {
        $script:capturedBranch = $null
        Mock Write-GerberProgressBar {}
        Mock New-GerberAdoRepository { [pscustomobject]@{ Success = $true; RepoId = 'new-repo' } }
        Mock Get-GerberAdoRepositoryItemTree {
            $script:capturedBranch = $BranchName
            [pscustomobject]@{ Success = $true; FileTree = @() }
        }
        Mock New-GerberAdoRepositoryInitialCommit { [pscustomobject]@{ Success = $true } }
        Mock New-GerberAdoPipelinesFromTemplate { [pscustomobject]@{ Success = $true; PipelineMap = @{} } }
        Mock New-GerberAdoRepositoryBranchSet { [pscustomobject]@{ Success = $true } }
        Mock Set-GerberAdoRepositoryCreateDefaultBranch { [pscustomobject]@{ Success = $true } }
        Mock Copy-GerberAdoPoliciesFromTemplate { [pscustomobject]@{ Success = $true } }

        $context = New-RepositoryCreateContext -Template ([pscustomobject]@{ Id = 'tpl'; DefaultBranch = 'refs/heads/develop' })
        $null = Invoke-GerberRepositoryCreateApplyWithProgress -Context $context

        $script:capturedBranch | Should -Be 'develop'
    }

    It 'returns early with a repo-creation failure when New-GerberAdoRepository fails' {
        Mock Write-GerberProgressBar {}
        Mock New-GerberAdoRepository { [pscustomobject]@{ Success = $false; ErrorDetail = 'Conflict' } }
        Mock Get-GerberAdoRepositoryItemTree {}
        Mock New-GerberAdoRepositoryInitialCommit {}
        Mock New-GerberAdoPipelinesFromTemplate {}
        Mock New-GerberAdoRepositoryBranchSet {}
        Mock Set-GerberAdoRepositoryCreateDefaultBranch {}
        Mock Copy-GerberAdoPoliciesFromTemplate {}

        $context = New-RepositoryCreateContext -Template ([pscustomobject]@{ Id = 'tpl'; DefaultBranch = 'refs/heads/develop' })
        $result = Invoke-GerberRepositoryCreateApplyWithProgress -Context $context

        $result.Failures.Count | Should -Be 1
        $result.Failures[0] | Should -Be 'Create repository: Conflict'
        Should -Invoke Get-GerberAdoRepositoryItemTree -Times 0
    }

    It 'accumulates failures for every step that fails after repository creation' {
        Mock Write-GerberProgressBar {}
        Mock New-GerberAdoRepository { [pscustomobject]@{ Success = $true; RepoId = 'new-repo' } }
        Mock Get-GerberAdoRepositoryItemTree { [pscustomobject]@{ Success = $false; ErrorDetail = 'Fetch error'; FileTree = @() } }
        Mock New-GerberAdoRepositoryInitialCommit { [pscustomobject]@{ Success = $false; ErrorDetail = 'Commit error' } }
        Mock New-GerberAdoPipelinesFromTemplate { [pscustomobject]@{ Success = $false; ErrorDetail = 'Pipeline error'; PipelineMap = @{} } }
        Mock New-GerberAdoRepositoryBranchSet { [pscustomobject]@{ Success = $false; ErrorDetail = 'Branch error' } }
        Mock Set-GerberAdoRepositoryCreateDefaultBranch { [pscustomobject]@{ Success = $false } }
        Mock Copy-GerberAdoPoliciesFromTemplate { [pscustomobject]@{ Success = $false; ErrorDetail = 'Policy error' } }

        $context = New-RepositoryCreateContext -Template ([pscustomobject]@{ Id = 'tpl'; DefaultBranch = 'refs/heads/develop' })
        $result = Invoke-GerberRepositoryCreateApplyWithProgress -Context $context

        $result.Failures.Count | Should -Be 6
        $result.Failures | Should -Contain 'Fetch files: Fetch error'
        $result.Failures | Should -Contain 'Initial commit: Commit error'
        $result.Failures | Should -Contain 'Create pipelines: Pipeline error'
        $result.Failures | Should -Contain 'Create branches: Branch error'
        $result.Failures | Should -Contain 'Set default branch'
        $result.Failures | Should -Contain 'Copy policies: Policy error'
    }
}

Describe 'Invoke-GerberRepositoryCreateFromTemplateIteration' {
    It 'returns true when <Scenario>' -ForEach @(
        @{
            Scenario = 'repository-name input is cancelled'
            RepositoryName = $null
            TeamSelection = [pscustomobject]@{ Id = 't1'; Name = 'TeamA' }
            ExpectedMock = 'Read-GerberRepositoryCreateRepositoryNameOrNull'
        }
        @{
            Scenario = 'team selection is cancelled'
            RepositoryName = 'MyPkg'
            TeamSelection = $null
            ExpectedMock = 'Read-GerberRepositoryCreateTeamOrNull'
        }
    ) {
        Mock Write-GerberPromptTrace {}
        Mock Read-GerberRepositoryCreateRepositoryNameOrNull { $RepositoryName }
        Mock Read-GerberRepositoryCreateTeamOrNull { $TeamSelection }

        $result = Invoke-GerberRepositoryCreateFromTemplateIteration `
            -ProjectSelection ([pscustomobject]@{ Id = 'p1'; Name = 'Proj' }) `
            -TemplateSelection ([pscustomobject]@{ Id = '1'; Name = 'Template_NuGet' })

        $result | Should -BeTrue
        if ($ExpectedMock -eq 'Read-GerberRepositoryCreateRepositoryNameOrNull') {
            Should -Invoke Read-GerberRepositoryCreateRepositoryNameOrNull -Times 1
        } else {
            Should -Invoke Read-GerberRepositoryCreateTeamOrNull -Times 1
        }
    }

    It 'returns true when the user does not confirm the apply step' {
        Mock Write-GerberPromptTrace {}
        Mock Read-GerberRepositoryCreateRepositoryNameOrNull { 'MyPkg' }
        Mock Read-GerberRepositoryCreateTeamOrNull { [pscustomobject]@{ Id = 't1'; Name = 'TeamA' } }
        Mock Build-GerberRepositoryCreateContext { [pscustomobject]@{ RepositoryName = 'MyPkg' } }
        Mock Show-GerberRepositoryCreatePreview {}
        Mock Confirm-GerberRepositoryCreateApply { $false }

        $result = Invoke-GerberRepositoryCreateFromTemplateIteration `
            -ProjectSelection ([pscustomobject]@{ Id = 'p1'; Name = 'Proj' }) `
            -TemplateSelection ([pscustomobject]@{ Id = '1'; Name = 'Template_NuGet' })

        $result | Should -BeTrue
        Should -Invoke Confirm-GerberRepositoryCreateApply -Times 1
    }

    It 'applies and returns the continue result when the user confirms' {
        Mock Write-GerberPromptTrace {}
        Mock Read-GerberRepositoryCreateRepositoryNameOrNull { 'MyPkg' }
        Mock Read-GerberRepositoryCreateTeamOrNull { [pscustomobject]@{ Id = 't1'; Name = 'TeamA' } }
        Mock Build-GerberRepositoryCreateContext { [pscustomobject]@{ RepositoryName = 'MyPkg' } }
        Mock Show-GerberRepositoryCreatePreview {}
        Mock Confirm-GerberRepositoryCreateApply { $true }
        Mock Show-GerberRepositoryCreateApplyScreen {}
        Mock Invoke-GerberRepositoryCreateApplyWithProgress { [pscustomobject]@{ Failures = @() } }
        Mock Show-GerberRepositoryCreateApplyResult {}
        Mock Wait-GerberRepositoryCreateContinue { $false }

        $result = Invoke-GerberRepositoryCreateFromTemplateIteration `
            -ProjectSelection ([pscustomobject]@{ Id = 'p1'; Name = 'Proj' }) `
            -TemplateSelection ([pscustomobject]@{ Id = '1'; Name = 'Template_NuGet' })

        $result | Should -BeFalse
        Should -Invoke Show-GerberRepositoryCreateApplyScreen -Times 1
        Should -Invoke Invoke-GerberRepositoryCreateApplyWithProgress -Times 1
        Should -Invoke Show-GerberRepositoryCreateApplyResult -Times 1
        Should -Invoke Wait-GerberRepositoryCreateContinue -Times 1
    }
}

Describe 'Repository-create route header screens' {
    It 'clears the host and writes the generic repository-create route header line for <FunctionName>' -ForEach @(
        @{ FunctionName = 'Show-GerberRepositoryCreateFromTemplateHeader' }
        @{ FunctionName = 'Show-GerberRepositoryCreateApplyScreen' }
    ) {
        Mock Start-GerberScreen {}
        Mock Write-GerberScreenLine {}

        & $FunctionName

        Should -Invoke Start-GerberScreen -Times 1 -ParameterFilter { $Name -eq '/repository create' }
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq '/repository create' }
        Should -Invoke Write-GerberScreenLine -Times 2
    }
}

Describe 'Show-GerberRepositoryCreateApplyResult' {
    It 'writes a success message when there are no failures' {
        Mock Clear-Host {}
        Mock Write-GerberScreenLine {}

        Show-GerberRepositoryCreateApplyResult -Results ([pscustomobject]@{ Failures = @() })

        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq 'Repository created successfully.' }
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq '/repository create' }
    }

    It 'writes a failure summary and each failure detail when failures exist' {
        Mock Clear-Host {}
        Mock Write-GerberScreenLine {}

        Show-GerberRepositoryCreateApplyResult -Results ([pscustomobject]@{
            Failures = @('Create repository: Conflict', 'Fetch files: Error')
        })

        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -like 'Repository created with 2 failure*' }
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq '  [!] Create repository: Conflict' }
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq '  [!] Fetch files: Error' }
    }
}

Describe 'Invoke-GerberRepositoryCreateStep' {
    It 'does not add to failures when result is successful' {
        $failures = [System.Collections.Generic.List[string]]::new()
        $result = [pscustomobject]@{ Success = $true }

        Invoke-GerberRepositoryCreateStep -Failures $failures -Label 'My step' -Result $result

        $failures.Count | Should -Be 0
    }

    It 'adds label-only to failures when result fails and IncludeErrorDetail is not set' {
        $failures = [System.Collections.Generic.List[string]]::new()
        $result = [pscustomobject]@{ Success = $false; ErrorDetail = 'Something went wrong' }

        Invoke-GerberRepositoryCreateStep -Failures $failures -Label 'My step' -Result $result

        $failures.Count | Should -Be 1
        $failures[0] | Should -Be 'My step'
    }

    It 'adds label with error detail when result fails and IncludeErrorDetail is set' {
        $failures = [System.Collections.Generic.List[string]]::new()
        $result = [pscustomobject]@{ Success = $false; ErrorDetail = 'Something went wrong' }

        Invoke-GerberRepositoryCreateStep -Failures $failures -Label 'My step' -Result $result -IncludeErrorDetail

        $failures.Count | Should -Be 1
        $failures[0] | Should -Be 'My step: Something went wrong'
    }

    It 'adds label-only when result has no ErrorDetail property and IncludeErrorDetail is set' {
        $failures = [System.Collections.Generic.List[string]]::new()
        $result = [pscustomobject]@{ Success = $false }

        Invoke-GerberRepositoryCreateStep -Failures $failures -Label 'My step' -Result $result -IncludeErrorDetail

        $failures.Count | Should -Be 1
        $failures[0] | Should -Be 'My step'
    }
}

Describe 'Resolve-GerberBuildPolicyDisplayName' {
    It 'resolves build policy display names for <Scenario>' -ForEach @(
        @{
            Scenario = 'template-name and legacy placeholder replacement'
            Context = [pscustomobject]@{ RepositoryName = 'MyPkg'; Template = [pscustomobject]@{ Name = 'Template_NuGet' } }
            TemplateDisplayName = 'Template_NuGet (build and publish)'
            Expected = 'MyPkg (build and publish)'
        }
        @{
            Scenario = 'legacy PackageName placeholder replacement without template name'
            Context = [pscustomobject]@{ RepositoryName = 'MyPkg'; Template = [pscustomobject]@{ Id = 'tpl' } }
            TemplateDisplayName = 'PackageName (build and publish)'
            Expected = 'MyPkg (build and publish)'
        }
    ) {
        $result = Resolve-GerberBuildPolicyDisplayName -Context $Context -TemplateDisplayName $TemplateDisplayName

        $result | Should -Be $Expected
    }
}

Describe 'Copy-GerberAdoBuildValidationPolicy' {
    It 'returns without calling New-GerberAdoPolicyConfiguration when pipeline definition lookup fails' {
        Mock Get-GerberAdoPipelineDefinition { [pscustomobject]@{ Success = $false; YamlPath = '' } }
        Mock New-GerberAdoPolicyConfiguration { [pscustomobject]@{ Success = $true } }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{ CredentialIdentifier = 'PAT' }
            Pat = 'test-pat'
            RepositoryName = 'MyPkg'
            Template = [pscustomobject]@{ Id = 'tpl'; Name = 'Template_NuGet' }
            Team = [pscustomobject]@{ Id = 'team1' }
        }
        $policy = [pscustomobject]@{
            Id = 1
            Type = [pscustomobject]@{ id = 'type-build' }
            Settings = [pscustomobject]@{
                buildDefinitionId = 42
                displayName = 'Template_NuGet (build)'
                scope = @()
            }
        }

        Copy-GerberAdoBuildValidationPolicy -Context $context -RepoId 'r1' -Policy $policy -PipelineMap @{}

        Should -Invoke New-GerberAdoPolicyConfiguration -Times 0
    }

    It 'returns without calling New-GerberAdoPolicyConfiguration when yaml path not in PipelineMap' {
        Mock Get-GerberAdoPipelineDefinition { [pscustomobject]@{ Success = $true; YamlPath = '/pipelines/other.yml' } }
        Mock New-GerberAdoPolicyConfiguration { [pscustomobject]@{ Success = $true } }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{ CredentialIdentifier = 'PAT' }
            Pat = 'test-pat'
            RepositoryName = 'MyPkg'
            Template = [pscustomobject]@{ Id = 'tpl'; Name = 'Template_NuGet' }
            Team = [pscustomobject]@{ Id = 'team1' }
        }
        $policy = [pscustomobject]@{
            Id = 2
            Type = [pscustomobject]@{ id = 'type-build' }
            Settings = [pscustomobject]@{
                buildDefinitionId = 42
                displayName = 'Template_NuGet (build)'
                scope = @()
            }
        }

        Copy-GerberAdoBuildValidationPolicy -Context $context -RepoId 'r1' -Policy $policy -PipelineMap @{ '/pipelines/build.yml' = @{ Id = 99; Name = 'MyPkg (build)' } }

        Should -Invoke New-GerberAdoPolicyConfiguration -Times 0
    }

    It 'calls New-GerberAdoPolicyConfiguration with remapped buildDefinitionId and displayName' {
        $script:capturedPolicy = $null
        Mock Get-GerberAdoPipelineDefinition { [pscustomobject]@{ Success = $true; YamlPath = '/pipelines/build.yml' } }
        Mock New-GerberAdoPolicyConfiguration {
            $script:capturedPolicy = $Policy
            [pscustomobject]@{ Success = $true }
        }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{ CredentialIdentifier = 'PAT' }
            Pat = 'test-pat'
            RepositoryName = 'MyPkg'
            Template = [pscustomobject]@{ Id = 'tpl'; Name = 'Template_NuGet' }
            Team = [pscustomobject]@{ Id = 'team1' }
        }
        $policy = [pscustomobject]@{
            Id = 3
            Type = [pscustomobject]@{ id = 'type-build' }
            Settings = [pscustomobject]@{
                buildDefinitionId = 42
                displayName = 'Template_NuGet (build)'
                scope = @()
            }
        }
        $pipelineMap = @{ '/pipelines/build.yml' = @{ Id = 77; Name = 'MyPkg (build)' } }

        Copy-GerberAdoBuildValidationPolicy -Context $context -RepoId 'r1' -Policy $policy -PipelineMap $pipelineMap

        Should -Invoke New-GerberAdoPolicyConfiguration -Times 1
        $script:capturedPolicy.Settings.buildDefinitionId | Should -Be 77
        $script:capturedPolicy.Settings.displayName | Should -Be 'MyPkg (build)'
    }
}

Describe 'Add-GerberAdoRequiredReviewerPolicy' {
    It 'applies required-reviewer policies for <Scenario>' -ForEach @(
        @{
            Scenario = 'repositories with branches'
            BranchList = @('refs/heads/main', 'refs/heads/develop')
            ExpectedCalls = 2
        }
        @{
            Scenario = 'repositories without branches'
            BranchList = @()
            ExpectedCalls = 0
        }
    ) {
        Mock Get-GerberAdoRepositoryBranchList { $BranchList }
        Mock New-GerberAdoPolicyConfiguration { [pscustomobject]@{ Success = $true } }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{ CredentialIdentifier = 'PAT' }
            Pat = 'test-pat'
            Team = [pscustomobject]@{ Id = 'team1' }
        }

        Add-GerberAdoRequiredReviewerPolicy -Context $context -RepoId 'r1' -RequiredReviewerTypeId 'fd2167ab-b0be-447a-8ec8-39368250530e'

        Should -Invoke New-GerberAdoPolicyConfiguration -Times $ExpectedCalls
    }

    It 'constructs reviewer policy with correct type id and branch ref' {
        $script:capturedPolicies = @()
        Mock Get-GerberAdoRepositoryBranchList { @('refs/heads/main') }
        Mock New-GerberAdoPolicyConfiguration {
            $script:capturedPolicies += $Policy
            [pscustomobject]@{ Success = $true }
        }

        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{ CredentialIdentifier = 'PAT' }
            Pat = 'test-pat'
            Team = [pscustomobject]@{ Id = 'team1' }
        }

        Add-GerberAdoRequiredReviewerPolicy -Context $context -RepoId 'r1' -RequiredReviewerTypeId 'fd2167ab-b0be-447a-8ec8-39368250530e'

        $script:capturedPolicies[0].Type.id | Should -Be 'fd2167ab-b0be-447a-8ec8-39368250530e'
        $script:capturedPolicies[0].Settings.scope[0].refName | Should -Be 'refs/heads/main'
    }

}
