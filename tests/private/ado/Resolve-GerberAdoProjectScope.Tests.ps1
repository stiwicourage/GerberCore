BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Resolve-GerberAdoProjectScope' {
    It 'returns <ExpectedValue> when <Scenario>' -ForEach @(
        @{
            Scenario = 'the selected project ID is preferred during repository-create operations'
            Context = [pscustomobject]@{
                Configuration = [pscustomobject]@{ ProjectName = 'Project-A' }
                Project = [pscustomobject]@{ Id = 'project-b-id'; Name = 'Project-B' }
            }
            PreferName = $false
            ExpectedValue = 'project-b-id'
        }
        @{
            Scenario = 'the selected project name is requested explicitly'
            Context = [pscustomobject]@{
                Configuration = [pscustomobject]@{ ProjectName = 'Project-A' }
                Project = [pscustomobject]@{ Id = 'project-b-id'; Name = 'Project-B' }
            }
            PreferName = $true
            ExpectedValue = 'Project-B'
        }
        @{
            Scenario = 'PreferName is set but the selected project name is unavailable'
            Context = [pscustomobject]@{
                Configuration = [pscustomobject]@{ ProjectName = 'Project-A' }
                Project = [pscustomobject]@{ Id = 'project-b-id' }
            }
            PreferName = $true
            ExpectedValue = 'project-b-id'
        }
        @{
            Scenario = 'the selected project ID is unavailable'
            Context = [pscustomobject]@{
                Configuration = [pscustomobject]@{ ProjectName = 'Project-A' }
                Project = [pscustomobject]@{ Name = 'Project-B' }
            }
            PreferName = $false
            ExpectedValue = 'Project-B'
        }
    ) {
        $result = if ($PreferName) {
            Resolve-GerberAdoProjectScope -Context $Context -PreferName
        } else {
            Resolve-GerberAdoProjectScope -Context $Context
        }

        $result | Should -Be $ExpectedValue
    }

    It 'falls back to the configured default project when no selected project exists' {
        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{ ProjectName = 'Project-A' }
        }

        $result = Resolve-GerberAdoProjectScope -Context $context

        $result | Should -Be 'Project-A'
    }

    It 'throws when the selected project is missing both ID and name' {
        $context = [pscustomobject]@{
            Configuration = [pscustomobject]@{ ProjectName = 'Project-A' }
            Project = [pscustomobject]@{ Id = ''; Name = '' }
        }

        { Resolve-GerberAdoProjectScope -Context $context } | Should -Throw 'Azure DevOps project selection is missing both Id and Name.'
    }
}
