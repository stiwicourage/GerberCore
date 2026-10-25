BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Resolve-GerberAdoPullRequestReference' {
    BeforeEach {
        $script:configuration = [pscustomobject]@{
            ProjectName = 'ExampleProject'
            CollectionName = 'ExampleProject'
            DeploymentType = 'Server'
            ServerUrl = [uri]'https://ado.example.test'
            ServerUri = [uri]'https://ado.example.test'
            CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
        }
    }

    It 'treats a numeric input as a pull request ID in the configured project' {
        $result = Resolve-GerberAdoPullRequestReference -InputText '18075' -Configuration $script:configuration

        $result.PullRequestId | Should -Be 18075
        $result.ProjectName | Should -Be 'ExampleProject'
        $result.RepositoryName | Should -BeNullOrEmpty
    }

    It 'parses a full Azure DevOps pull request URL' {
        $result = Resolve-GerberAdoPullRequestReference `
            -InputText 'https://ado.example.test/ExampleProject/ExampleProject/_git/Repo/pullrequest/18075' `
            -Configuration $script:configuration

        $result.PullRequestId | Should -Be 18075
        $result.ProjectName | Should -Be 'ExampleProject'
        $result.RepositoryName | Should -Be 'Repo'
    }

    It 'rejects URLs from another host or root' {
        {
            Resolve-GerberAdoPullRequestReference `
                -InputText 'https://example.com/ExampleProject/ExampleProject/_git/Repo/pullrequest/18075' `
                -Configuration $script:configuration
        } | Should -Throw '*does not belong to the explicit Azure DevOps Server root*'
    }

    It 'rejects blank input before attempting to parse a reference' {
        {
            Resolve-GerberAdoPullRequestReference -InputText '   ' -Configuration $script:configuration
        } | Should -Throw '*Enter a pull request number*'
    }
}

Describe 'ConvertTo-GerberAdoPullRequestReferenceFromUrl' {
    It 'rejects non-URL input' {
        {
            ConvertTo-GerberAdoPullRequestReferenceFromUrl `
                -InputText 'not a url' `
                -Configuration ([pscustomobject]@{
                    CollectionName = 'ExampleProject'
                    ServerUrl = [uri]'https://ado.example.test'
                    CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                })
        } | Should -Throw '*Enter a pull request number*'
    }

    It 'rejects pull request URLs from another collection' {
        {
            ConvertTo-GerberAdoPullRequestReferenceFromUrl `
                -InputText 'https://ado.example.test/Other/ExampleProject/_git/Repo/pullrequest/18075' `
                -Configuration ([pscustomobject]@{
                    CollectionName = 'ExampleProject'
                    DeploymentType = 'Server'
                    ServerUrl = [uri]'https://ado.example.test'
                    ServerUri = [uri]'https://ado.example.test'
                    CollectionUri = [uri]'https://ado.example.test/ExampleProject/'
                })
        } | Should -Throw "*collection 'ExampleProject'*"
    }

    It 'parses pull request URLs below a custom server root' {
        $result = ConvertTo-GerberAdoPullRequestReferenceFromUrl `
            -InputText 'https://ado.example.com/azuredevops/DefaultCollection/MyProject/_git/Repo/pullrequest/18075' `
            -Configuration ([pscustomobject]@{
                    ProjectName = 'MyProject'
                    CollectionName = 'DefaultCollection'
                    DeploymentType = 'Server'
                    ServerUrl = [uri]'https://ado.example.com/azuredevops'
                    ServerUri = [uri]'https://ado.example.com/azuredevops'
                    CollectionUri = [uri]'https://ado.example.com/azuredevops/DefaultCollection/'
                })

        $result.ProjectName | Should -Be 'MyProject'
        $result.RepositoryName | Should -Be 'Repo'
        $result.PullRequestId | Should -Be 18075
    }
}

Describe 'Get-GerberAdoPullRequestUrlSegmentList' {
    It 'removes empty path segments and decodes escaped names' {
        $segmentList = Get-GerberAdoPullRequestUrlSegmentList -ResolvedUri ([uri]'https://ado.example.test/ExampleProject/Project/_git/My%20Repo/pullrequest/18075')

        $segmentList | Should -Be @('ExampleProject', 'Project', '_git', 'My Repo', 'pullrequest', '18075')
    }
}

Describe 'Assert-GerberAdoPullRequestUrlPath' {
    BeforeEach {
        $script:configuration = [pscustomobject]@{
            CollectionUri = [uri]'https://ado.example.com/Contoso/'
        }
    }

    It 'rejects URLs that are missing the git repository segment' {
        {
            Assert-GerberAdoPullRequestUrlPath `
                -SegmentList @('Contoso', 'Project', 'pullrequest', '18075') `
                -Configuration $script:configuration
        } | Should -Throw '*full Azure DevOps pull request URL*'
    }

    It 'rejects URLs that are missing the pull request id segment' {
        {
            Assert-GerberAdoPullRequestUrlPath `
                -SegmentList @('Contoso', 'Project', '_git', 'Repo', 'pullrequest') `
                -Configuration $script:configuration
        } | Should -Throw '*full Azure DevOps pull request URL*'
    }

    It 'uses the configured collection URI in the guidance instead of a hard-coded host' {
        {
            Assert-GerberAdoPullRequestUrlPath `
                -SegmentList @('Contoso', 'Project', 'pullrequest', '18075') `
                -Configuration $script:configuration
        } | Should -Throw '*https://ado.example.com/Contoso/<project>/_git/<repo>/pullrequest/<id>*'
    }
}

Describe 'Get-GerberAdoPullRequestUrlGuidance' {
    It 'derives the example URL from the configured collection URI' {
        $result = Get-GerberAdoPullRequestUrlGuidance -Configuration ([pscustomobject]@{
                CollectionUri = [uri]'https://ado.example.com/Contoso/'
            })

        $result | Should -Be 'Enter a full Azure DevOps pull request URL in the form https://ado.example.com/Contoso/<project>/_git/<repo>/pullrequest/<id>.'
        $result | Should -Not -Match 'ado\.example\.test'
    }
}

Describe 'Get-GerberAdoPullRequestIdText' {
    It 'rejects URLs whose pull request id is not numeric' {
        {
            Get-GerberAdoPullRequestIdText `
                -SegmentList @('ExampleProject', 'Project', '_git', 'Repo', 'pullrequest', 'abc') `
                -GitIndex 2 `
                -InputText 'https://ado.example.test/ExampleProject/Project/_git/Repo/pullrequest/abc'
        } | Should -Throw "*could not read a numeric pull request ID*"
    }
}
