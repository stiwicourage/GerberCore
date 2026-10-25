BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

function global:New-GerberAdoPipelineTestContext {
    param(
        [string]$RepositoryName = 'MyPackage'
    )

    return [pscustomobject]@{
        Configuration = [pscustomobject]@{
            ProjectName = 'Project-A'
            CredentialIdentifier = 'PAT'
        }
        Pat = 'test-pat'
        Project = [pscustomobject]@{ Id = 'project-b-id'; Name = 'Project-B' }
        RepositoryName = $RepositoryName
    }
}

function global:Set-GerberAdoPipelineSuccessMockSet {
    param(
        [switch]$CaptureBody
    )

    Mock Get-GerberAdoBranchRequestUri { [uri]'https://example.test/api' }
    Mock Get-GerberHttpConfiguration { [pscustomobject]@{ ConnectionTimeoutSeconds = 5; OperationTimeoutSeconds = 15 } }
    Mock Get-GerberAdoRequestHeader { @{} }

    if ($CaptureBody) {
        $script:capturedBody = $null
        Mock ConvertTo-Json {
            $script:capturedBody = $InputObject
            '{"name":"captured"}'
        }
    }

    Mock Invoke-RestMethod { @{ id = 1 } }
}

function global:Invoke-GerberAdoPipelineAndCaptureBody {
    param(
        [string]$YamlPath,
        [string]$DefaultBranchRef = 'refs/heads/main',
        [string]$RepositoryName = 'MyPackage'
    )

    Set-GerberAdoPipelineSuccessMockSet -CaptureBody
    $context = New-GerberAdoPipelineTestContext -RepositoryName $RepositoryName

    $null = New-GerberAdoPipeline `
        -Context $context `
        -RepoId 'r1' `
        -YamlPath $YamlPath `
        -DefaultBranchRef $DefaultBranchRef

    return $script:capturedBody
}

Describe 'New-GerberAdoPipeline' {
    It 'returns success with PipelineId when pipeline creation succeeds' {
        Set-GerberAdoPipelineSuccessMockSet
        Mock Invoke-RestMethod { @{ id = 42 } }

        $result = New-GerberAdoPipeline `
            -Context (New-GerberAdoPipelineTestContext -RepositoryName 'TestPkg') `
            -RepoId 'r1' `
            -YamlPath 'pipelines/build.yml' `
            -DefaultBranchRef 'refs/heads/main'

        $result.Success | Should -BeTrue
        $result.PipelineId | Should -Be 42
    }

    It 'names the pipeline as RepositoryName (stem with dashes as spaces)' {
        $capturedBody = Invoke-GerberAdoPipelineAndCaptureBody -YamlPath 'pipelines/build-and-publish.yml'

        $capturedBody.name | Should -Be 'MyPackage (build and publish)'
    }

    It 'preserves repository configuration details for <Scenario>' -ForEach @(
        @{
            Scenario = 'a path without a leading slash'
            YamlPath = 'pipelines/build.yml'
            DefaultBranchRef = 'refs/heads/main'
            Assertion = {
                param($CapturedBody)
                $CapturedBody.configuration.path | Should -Be '/pipelines/build.yml'
            }
        }
        @{
            Scenario = 'a path that already starts with a slash'
            YamlPath = '/pipelines/build.yml'
            DefaultBranchRef = 'refs/heads/main'
            Assertion = {
                param($CapturedBody)
                $CapturedBody.configuration.path | Should -Be '/pipelines/build.yml'
            }
        }
        @{
            Scenario = 'the selected default branch'
            YamlPath = 'pipelines/build.yml'
            DefaultBranchRef = 'refs/heads/develop'
            Assertion = {
                param($CapturedBody)
                $CapturedBody.configuration.repository.defaultBranch | Should -Be 'refs/heads/develop'
            }
        }
    ) {
        $capturedBody = Invoke-GerberAdoPipelineAndCaptureBody `
            -YamlPath $YamlPath `
            -DefaultBranchRef $DefaultBranchRef

        & $Assertion $capturedBody
    }

    It 'returns failure with ErrorDetail when pipeline creation throws exception' {
        Set-GerberAdoPipelineSuccessMockSet
        Mock Invoke-RestMethod { throw [System.InvalidOperationException]::new('API error') }
        Mock Get-GerberAdoRequestFailureMessage { 'Failure message' }

        $result = New-GerberAdoPipeline `
            -Context (New-GerberAdoPipelineTestContext -RepositoryName 'TestPkg') `
            -RepoId 'r1' `
            -YamlPath 'pipelines/build.yml' `
            -DefaultBranchRef 'refs/heads/main'

        $result.Success | Should -BeFalse
        $result.ErrorDetail | Should -Not -BeNullOrEmpty
    }

    It 'returns failure with the raw exception message when the URI cannot be built' {
        Mock Get-GerberAdoBranchRequestUri { throw [System.InvalidOperationException]::new('URI build failed') }

        $result = New-GerberAdoPipeline `
            -Context (New-GerberAdoPipelineTestContext -RepositoryName 'TestPkg') `
            -RepoId 'r1' `
            -YamlPath 'pipelines/build.yml' `
            -DefaultBranchRef 'refs/heads/main'

        $result.Success | Should -BeFalse
        $result.ErrorDetail | Should -Be 'URI build failed'
    }

    It 'uses the selected project scope for pipeline creation when configuration points elsewhere' {
        $script:capturedRelativePath = $null
        Mock Get-GerberAdoBranchRequestUri {
            $script:capturedRelativePath = $RelativePath
            [uri]'https://example.test/api'
        }
        Mock Get-GerberHttpConfiguration { [pscustomobject]@{ ConnectionTimeoutSeconds = 5; OperationTimeoutSeconds = 15 } }
        Mock Get-GerberAdoRequestHeader { @{} }
        Mock Invoke-RestMethod { @{ id = 1 } }

        $null = New-GerberAdoPipeline `
            -Context (New-GerberAdoPipelineTestContext -RepositoryName 'TestPkg') `
            -RepoId 'r1' `
            -YamlPath 'pipelines/build.yml' `
            -DefaultBranchRef 'refs/heads/main'

        $script:capturedRelativePath | Should -Be 'project-b-id/_apis/pipelines'
    }
}
