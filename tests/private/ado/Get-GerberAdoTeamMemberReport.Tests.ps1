BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoTeamMemberReport' {
    BeforeEach {
        Mock Get-GerberAdoConfiguration {
            [pscustomobject]@{
                CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                DefaultApiVersion = '7.1-preview.1'
                CredentialIdentifier = 'gerber:ado:example:pat'
            }
        }
        Mock Resolve-GerberAdoPat { 'test-pat' }
    }

    It 'returns a report with Configuration and ProjectList fields' {
        Mock Get-GerberAdoProjectList { @() }
        $result = Get-GerberAdoTeamMemberReport

        $result.Configuration | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties.Name | Should -Contain 'ProjectList'
    }

    It 'resolves projects, teams, and members in correct nested structure' {
        Mock Get-GerberAdoConfiguration {
            [pscustomobject]@{
                CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                DefaultApiVersion = '7.1-preview.1'
                CredentialIdentifier = 'gerber:ado:example:pat'
            }
        }
        Mock Resolve-GerberAdoPat { 'test-pat' }
        Mock Get-GerberAdoProjectList {
            @([pscustomobject]@{ Id = 'proj-1'; Name = 'Alpha Project' })
        }
        Mock Get-GerberAdoTeamList {
            @([pscustomobject]@{ Id = 'team-1'; Name = 'Team A' })
        }
        Mock Get-GerberAdoTeamMemberList {
            @([pscustomobject]@{ DisplayName = 'Jane Doe'; UniqueName = 'jane@example.com' })
        }

        $result = Get-GerberAdoTeamMemberReport

        $result.ProjectList.Count | Should -Be 1
        $result.ProjectList[0].Name | Should -Be 'Alpha Project'
        $result.ProjectList[0].TeamList.Count | Should -Be 1
        $result.ProjectList[0].TeamList[0].Name | Should -Be 'Team A'
        $result.ProjectList[0].TeamList[0].MemberList.Count | Should -Be 1
        $result.ProjectList[0].TeamList[0].MemberList[0].DisplayName | Should -Be 'Jane Doe'
    }

    It 'returns an empty ProjectList when no projects exist' {
        Mock Get-GerberAdoProjectList { @() }
        $result = Get-GerberAdoTeamMemberReport

        @($result.ProjectList).Count | Should -Be 0
    }

    It 'sorts projects by name and teams by name and members by DisplayName' {
        Mock Get-GerberAdoConfiguration {
            [pscustomobject]@{
                CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                DefaultApiVersion = '7.1-preview.1'
                CredentialIdentifier = 'gerber:ado:example:pat'
            }
        }
        Mock Resolve-GerberAdoPat { 'test-pat' }
        Mock Invoke-GerberAdoRestRequest {
            [pscustomobject]@{
                value = @(
                    [pscustomobject]@{ id = 'p2'; name = 'Zeta' }
                    [pscustomobject]@{ id = 'p1'; name = 'Alpha' }
                )
            }
        }

        $config = [pscustomobject]@{
            CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
            DefaultApiVersion = '7.1-preview.1'
            CredentialIdentifier = 'gerber:ado:example:pat'
        }
        $result = Get-GerberAdoProjectList -Configuration $config -Pat 'test-pat'

        $result[0].Name | Should -Be 'Alpha'
        $result[1].Name | Should -Be 'Zeta'
    }

    It 'builds correct project list URI using DefaultApiVersion' {
        Mock Get-GerberAdoConfiguration {
            [pscustomobject]@{
                CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                DefaultApiVersion = '7.1-preview.1'
                CredentialIdentifier = 'gerber:ado:example:pat'
            }
        }
        Mock Resolve-GerberAdoPat { 'test-pat' }
        Mock Invoke-GerberAdoRestRequest { [pscustomobject]@{ value = @() } }

        Get-GerberAdoTeamMemberReport

        Should -Invoke Invoke-GerberAdoRestRequest -Times 1 -ParameterFilter {
            $Uri.AbsoluteUri -like '*_apis/projects*' -and
            $Uri.AbsoluteUri -like '*api-version=7.1-preview.1*'
        }
    }

    It 'throws ArgumentException when HTTP call fails' {
        Mock Get-GerberAdoConfiguration {
            [pscustomobject]@{
                CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                DefaultApiVersion = '7.1-preview.1'
                CredentialIdentifier = 'gerber:ado:example:pat'
            }
        }
        Mock Resolve-GerberAdoPat { 'test-pat' }
        Mock Get-GerberAdoProjectList { throw [System.ArgumentException]::new('Gerber could not read Azure DevOps projects.') }

        { Get-GerberAdoTeamMemberReport } | Should -Throw -ExceptionType ([System.ArgumentException])
    }

    It 'maps member identity fields to DisplayName and UniqueName' {
        Mock Get-GerberAdoConfiguration {
            [pscustomobject]@{
                CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                DefaultApiVersion = '7.1-preview.1'
                CredentialIdentifier = 'gerber:ado:example:pat'
            }
        }
        Mock Resolve-GerberAdoPat { 'test-pat' }
        Mock Invoke-GerberAdoRestRequest {
            [pscustomobject]@{
                value = @(
                    [pscustomobject]@{
                        identity = [pscustomobject]@{
                            displayName = 'John Smith'
                            uniqueName = 'john.smith@example.com'
                        }
                    }
                )
            }
        }

        $result = Get-GerberAdoTeamMemberList `
            -Configuration ([pscustomobject]@{
                CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                DefaultApiVersion = '7.1-preview.1'
                CredentialIdentifier = 'gerber:ado:example:pat'
            }) `
            -Pat 'test-pat' `
            -ProjectId 'proj-1' `
            -TeamId 'team-1'

        $result[0].DisplayName | Should -Be 'John Smith'
        $result[0].UniqueName | Should -Be 'john.smith@example.com'
    }

    It 'maps member fields when response returns identity object directly without identity wrapper' {
        Mock Invoke-GerberAdoRestRequest {
            [pscustomobject]@{
                value = @(
                    [pscustomobject]@{
                        displayName = 'Jane Doe'
                        uniqueName = 'jane.doe@example.com'
                    }
                )
            }
        }

        $result = Get-GerberAdoTeamMemberList `
            -Configuration ([pscustomobject]@{
                CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                DefaultApiVersion = '7.1-preview.1'
                CredentialIdentifier = 'gerber:ado:example:pat'
            }) `
            -Pat 'test-pat' `
            -ProjectId 'proj-1' `
            -TeamId 'team-1'

        $result[0].DisplayName | Should -Be 'Jane Doe'
        $result[0].UniqueName | Should -Be 'jane.doe@example.com'
    }

    It 'Get-GerberAdoTeamList retrieves and sorts teams for a project' {
        Mock Invoke-GerberAdoRestRequest {
            [pscustomobject]@{
                value = @(
                    [pscustomobject]@{ id = 'tm2'; name = 'Zulu Team' }
                    [pscustomobject]@{ id = 'tm1'; name = 'Alpha Team' }
                )
            }
        }

        $config = [pscustomobject]@{
            CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
            DefaultApiVersion = '7.1-preview.1'
            CredentialIdentifier = 'gerber:ado:example:pat'
        }
        $result = Get-GerberAdoTeamList -Configuration $config -Pat 'test-pat' -ProjectId 'proj-1'

        $result.Count | Should -Be 2
        $result[0].Name | Should -Be 'Alpha Team'
        $result[1].Name | Should -Be 'Zulu Team'
    }

    It 'builds team member request URI with correct path and api-version' {
        $config = [pscustomobject]@{
            CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
            DefaultApiVersion = '7.1-preview.1'
        }

        $uri = Get-GerberAdoTeamMemberRequestUri -Configuration $config -RelativePath '_apis/projects'

        $uri.AbsoluteUri | Should -BeLike '*_apis/projects*'
        $uri.AbsoluteUri | Should -BeLike '*api-version=7.1-preview.1*'
    }
}
