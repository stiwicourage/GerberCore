BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot

    function ConvertTo-TestGerberUriText {
        param(
            [Parameter(Mandatory)]
            [AllowNull()]
            [object]$UriValue
        )

        if ($null -eq $UriValue) {
            return $null
        }

        if ($UriValue -is [uri]) {
            return $UriValue.AbsoluteUri.TrimEnd('/')
        }

        return ([string]$UriValue).TrimEnd('/')
    }

    function Assert-TestGerberAdoProjectUrlResult {
        param(
            [Parameter(Mandatory)]
            [pscustomobject]$Result,

            [Parameter(Mandatory)]
            [string]$DeploymentType,

            [AllowNull()]
            [object]$Organization,

            [AllowNull()]
            [object]$Collection,

            [Parameter(Mandatory)]
            [string]$Project,

            [Parameter(Mandatory)]
            [string]$ServerUri,

            [Parameter(Mandatory)]
            [string]$ProjectUri
        )

        $Result.DeploymentType | Should -Be $DeploymentType
        $Result.Organization | Should -Be $Organization
        $Result.Collection | Should -Be $Collection
        $Result.Project | Should -Be $Project
        $Result.ServerUri | Should -BeOfType ([uri])
        $Result.ProjectUri | Should -BeOfType ([uri])
        (ConvertTo-TestGerberUriText -UriValue $Result.ServerUri) | Should -Be $ServerUri
        (ConvertTo-TestGerberUriText -UriValue $Result.ProjectUri) | Should -Be $ProjectUri
    }
}

Describe 'Resolve-GerberAdoProjectUrl' {
    Context 'Azure DevOps Services URLs' {
        It 'parses <Scenario>' -ForEach @(
            @{
                Scenario = 'a modern project URL'
                Url = 'https://dev.azure.com/myorganization/MyProject'
                DeploymentType = 'Services'
                Organization = 'myorganization'
                Collection = $null
                Project = 'MyProject'
                ServerUri = 'https://dev.azure.com'
                ProjectUri = 'https://dev.azure.com/myorganization/MyProject'
            }
            @{
                Scenario = 'a modern project URL with an encoded project name'
                Url = 'https://dev.azure.com/myorganization/My%20Project'
                DeploymentType = 'Services'
                Organization = 'myorganization'
                Collection = $null
                Project = 'My Project'
                ServerUri = 'https://dev.azure.com'
                ProjectUri = 'https://dev.azure.com/myorganization/My%20Project'
            }
            @{
                Scenario = 'a legacy project URL'
                Url = 'https://myorganization.visualstudio.com/MyProject'
                DeploymentType = 'Services'
                Organization = 'myorganization'
                Collection = $null
                Project = 'MyProject'
                ServerUri = 'https://myorganization.visualstudio.com'
                ProjectUri = 'https://myorganization.visualstudio.com/MyProject'
            }
            @{
                Scenario = 'a legacy project URL with DefaultCollection'
                Url = 'https://myorganization.visualstudio.com/DefaultCollection/MyProject'
                DeploymentType = 'Services'
                Organization = 'myorganization'
                Collection = $null
                Project = 'MyProject'
                ServerUri = 'https://myorganization.visualstudio.com'
                ProjectUri = 'https://myorganization.visualstudio.com/DefaultCollection/MyProject'
            }
            @{
                Scenario = 'a project URL with a trailing slash'
                Url = 'https://dev.azure.com/myorganization/MyProject/'
                DeploymentType = 'Services'
                Organization = 'myorganization'
                Collection = $null
                Project = 'MyProject'
                ServerUri = 'https://dev.azure.com'
                ProjectUri = 'https://dev.azure.com/myorganization/MyProject'
            }
            @{
                Scenario = 'a repository URL'
                Url = 'https://dev.azure.com/myorganization/MyProject/_git/MyRepository'
                DeploymentType = 'Services'
                Organization = 'myorganization'
                Collection = $null
                Project = 'MyProject'
                ServerUri = 'https://dev.azure.com'
                ProjectUri = 'https://dev.azure.com/myorganization/MyProject'
            }
            @{
                Scenario = 'a pipeline URL'
                Url = 'https://dev.azure.com/myorganization/MyProject/_build'
                DeploymentType = 'Services'
                Organization = 'myorganization'
                Collection = $null
                Project = 'MyProject'
                ServerUri = 'https://dev.azure.com'
                ProjectUri = 'https://dev.azure.com/myorganization/MyProject'
            }
            @{
                Scenario = 'a boards URL'
                Url = 'https://dev.azure.com/myorganization/MyProject/_boards/board/t/MyTeam'
                DeploymentType = 'Services'
                Organization = 'myorganization'
                Collection = $null
                Project = 'MyProject'
                ServerUri = 'https://dev.azure.com'
                ProjectUri = 'https://dev.azure.com/myorganization/MyProject'
            }
            @{
                Scenario = 'a resource URL with a query string'
                Url = 'https://dev.azure.com/myorganization/MyProject/_git/MyRepository?path=/src'
                DeploymentType = 'Services'
                Organization = 'myorganization'
                Collection = $null
                Project = 'MyProject'
                ServerUri = 'https://dev.azure.com'
                ProjectUri = 'https://dev.azure.com/myorganization/MyProject'
            }
            @{
                Scenario = 'a project URL with a fragment'
                Url = 'https://dev.azure.com/myorganization/MyProject#section'
                DeploymentType = 'Services'
                Organization = 'myorganization'
                Collection = $null
                Project = 'MyProject'
                ServerUri = 'https://dev.azure.com'
                ProjectUri = 'https://dev.azure.com/myorganization/MyProject'
            }
        ) {
            $result = Resolve-GerberAdoProjectUrl -Url $Url

            Assert-TestGerberAdoProjectUrlResult `
                -Result $result `
                -DeploymentType $DeploymentType `
                -Organization $Organization `
                -Collection $Collection `
                -Project $Project `
                -ServerUri $ServerUri `
                -ProjectUri $ProjectUri
        }
    }

    Context 'Azure DevOps Server URLs' {
        It 'parses <Scenario>' -ForEach @(
            @{
                Scenario = 'a standard tfs project URL'
                Url = 'https://ado.example.test/tfs/DefaultCollection/MyProject'
                ServerRoot = $null
                AllowHttp = $false
                DeploymentType = 'Server'
                Organization = $null
                Collection = 'DefaultCollection'
                Project = 'MyProject'
                ServerUri = 'https://ado.example.test/tfs'
                ProjectUri = 'https://ado.example.test/tfs/DefaultCollection/MyProject'
            }
            @{
                Scenario = 'a host-root project URL with explicit server-root information'
                Url = 'https://ado.example.test/DefaultCollection/MyProject'
                ServerRoot = 'https://ado.example.test'
                AllowHttp = $false
                DeploymentType = 'Server'
                Organization = $null
                Collection = 'DefaultCollection'
                Project = 'MyProject'
                ServerUri = 'https://ado.example.test'
                ProjectUri = 'https://ado.example.test/DefaultCollection/MyProject'
            }
            @{
                Scenario = 'a custom virtual-directory project URL with explicit server-root information'
                Url = 'https://ado.example.test/azuredevops/DefaultCollection/MyProject'
                ServerRoot = 'https://ado.example.test/azuredevops'
                AllowHttp = $false
                DeploymentType = 'Server'
                Organization = $null
                Collection = 'DefaultCollection'
                Project = 'MyProject'
                ServerUri = 'https://ado.example.test/azuredevops'
                ProjectUri = 'https://ado.example.test/azuredevops/DefaultCollection/MyProject'
            }
            @{
                Scenario = 'a project URL with a non-default HTTPS port'
                Url = 'https://ado.example.test:8443/tfs/DefaultCollection/MyProject'
                ServerRoot = $null
                AllowHttp = $false
                DeploymentType = 'Server'
                Organization = $null
                Collection = 'DefaultCollection'
                Project = 'MyProject'
                ServerUri = 'https://ado.example.test:8443/tfs'
                ProjectUri = 'https://ado.example.test:8443/tfs/DefaultCollection/MyProject'
            }
            @{
                Scenario = 'a project URL whose project name contains spaces'
                Url = 'https://ado.example.test/tfs/DefaultCollection/My%20Project'
                ServerRoot = $null
                AllowHttp = $false
                DeploymentType = 'Server'
                Organization = $null
                Collection = 'DefaultCollection'
                Project = 'My Project'
                ServerUri = 'https://ado.example.test/tfs'
                ProjectUri = 'https://ado.example.test/tfs/DefaultCollection/My%20Project'
            }
            @{
                Scenario = 'a project URL whose project name contains Unicode characters'
                Url = 'https://ado.example.test/tfs/DefaultCollection/Pr%C3%B8ve'
                ServerRoot = $null
                AllowHttp = $false
                DeploymentType = 'Server'
                Organization = $null
                Collection = 'DefaultCollection'
                Project = ('Pr{0}ve' -f [char]0x00F8)
                ServerUri = 'https://ado.example.test/tfs'
                ProjectUri = 'https://ado.example.test/tfs/DefaultCollection/Pr%C3%B8ve'
            }
            @{
                Scenario = 'a recognized resource path below the project root'
                Url = 'https://ado.example.test/tfs/DefaultCollection/MyProject/_build/results?buildId=42'
                ServerRoot = $null
                AllowHttp = $false
                DeploymentType = 'Server'
                Organization = $null
                Collection = 'DefaultCollection'
                Project = 'MyProject'
                ServerUri = 'https://ado.example.test/tfs'
                ProjectUri = 'https://ado.example.test/tfs/DefaultCollection/MyProject'
            }
            @{
                Scenario = 'an HTTP self-hosted URL when explicit permission is granted'
                Url = 'http://ado.example.test/tfs/DefaultCollection/MyProject'
                ServerRoot = $null
                AllowHttp = $true
                DeploymentType = 'Server'
                Organization = $null
                Collection = 'DefaultCollection'
                Project = 'MyProject'
                ServerUri = 'http://ado.example.test/tfs'
                ProjectUri = 'http://ado.example.test/tfs/DefaultCollection/MyProject'
            }
            @{
                Scenario = 'a host-root project URL inferred without an explicit server root'
                Url = 'https://ado.example.test/DefaultCollection/MyProject'
                ServerRoot = $null
                AllowHttp = $false
                DeploymentType = 'Server'
                Organization = $null
                Collection = 'DefaultCollection'
                Project = 'MyProject'
                ServerUri = 'https://ado.example.test'
                ProjectUri = 'https://ado.example.test/DefaultCollection/MyProject'
            }
        ) {
            $parameter = @{
                Url = $Url
            }
            if (-not [string]::IsNullOrWhiteSpace($ServerRoot)) {
                $parameter.DeploymentType = 'Server'
                $parameter.ServerUri = $ServerRoot
            }

            if ($AllowHttp) {
                $parameter.AllowInsecureHttp = $true
            }

            $result = Resolve-GerberAdoProjectUrl @parameter

            Assert-TestGerberAdoProjectUrlResult `
                -Result $result `
                -DeploymentType $DeploymentType `
                -Organization $Organization `
                -Collection $Collection `
                -Project $Project `
                -ServerUri $ServerUri `
                -ProjectUri $ProjectUri
        }

        It 'requires explicit server-root information for an ambiguous self-hosted URL' {
            {
                Resolve-GerberAdoProjectUrl -Url 'https://ado.example.test/azuredevops/DefaultCollection/MyProject'
            } | Should -Throw '*could not determine the Azure DevOps Server root*'
        }

        It 'rejects a mismatched explicit server root' {
            {
                Resolve-GerberAdoProjectUrl `
                    -Url 'https://ado.example.test/tfs/DefaultCollection/MyProject' `
                    -DeploymentType Server `
                    -ServerUri 'https://ado.example.test/azuredevops'
            } | Should -Throw '*does not belong to the explicit Azure DevOps Server root*'
        }
    }

    Context 'invalid input' {
        It 'rejects <Scenario>' -ForEach @(
            @{
                Scenario = 'an empty URL'
                Action = {
                    Resolve-GerberAdoProjectUrl -Url ''
                }
                ErrorMessage = '*Provide a full Azure DevOps project URL.*'
            }
            @{
                Scenario = 'a whitespace-only URL'
                Action = {
                    Resolve-GerberAdoProjectUrl -Url '   '
                }
                ErrorMessage = '*Provide a full Azure DevOps project URL.*'
            }
            @{
                Scenario = 'a relative URL'
                Action = {
                    Resolve-GerberAdoProjectUrl -Url '/myorganization/MyProject'
                }
                ErrorMessage = '*Provide a full Azure DevOps project URL*'
            }
            @{
                Scenario = 'an invalid URI'
                Action = {
                    Resolve-GerberAdoProjectUrl -Url 'https://dev.azure.com:badport/myorganization/MyProject'
                }
                ErrorMessage = '*Provide a full Azure DevOps project URL*'
            }
            @{
                Scenario = 'an unsupported URL scheme'
                Action = {
                    Resolve-GerberAdoProjectUrl -Url 'ftp://dev.azure.com/myorganization/MyProject'
                }
                ErrorMessage = "*scheme 'ftp' is not supported*"
            }
            @{
                Scenario = 'an HTTP Azure DevOps Services URL'
                Action = {
                    Resolve-GerberAdoProjectUrl -Url 'http://dev.azure.com/myorganization/MyProject'
                }
                ErrorMessage = '*Services URLs must use HTTPS*'
            }
            @{
                Scenario = 'an HTTP Azure DevOps Server URL without explicit permission'
                Action = {
                    Resolve-GerberAdoProjectUrl -Url 'http://ado.example.test/tfs/DefaultCollection/MyProject'
                }
                ErrorMessage = '*AllowInsecureHttp*'
            }
            @{
                Scenario = 'a URL containing embedded credentials'
                Action = {
                    Resolve-GerberAdoProjectUrl -Url 'https://user:pass@ado.example.test/tfs/DefaultCollection/MyProject'
                }
                ErrorMessage = '*must not contain embedded credentials*'
            }
            @{
                Scenario = 'a modern services URL missing the organization'
                Action = {
                    Resolve-GerberAdoProjectUrl -Url 'https://dev.azure.com/MyProject'
                }
                ErrorMessage = '*must include both organization and project*'
            }
            @{
                Scenario = 'a modern services URL missing the project'
                Action = {
                    Resolve-GerberAdoProjectUrl -Url 'https://dev.azure.com/myorganization'
                }
                ErrorMessage = '*must include both organization and project*'
            }
            @{
                Scenario = 'malformed URI encoding'
                Action = {
                    Resolve-GerberAdoProjectUrl -Url 'https://dev.azure.com/myorganization/My%2Project'
                }
                ErrorMessage = '*malformed percent-encoding*'
            }
            @{
                Scenario = 'an unknown project resource path'
                Action = {
                    Resolve-GerberAdoProjectUrl -Url 'https://dev.azure.com/myorganization/MyProject/repositories/MyRepository'
                }
                ErrorMessage = '*does not identify a supported project resource*'
            }
            @{
                Scenario = 'a malformed self-hosted URL'
                Action = {
                    Resolve-GerberAdoProjectUrl -Url 'https://ado.example.test/tfs/DefaultCollection'
                }
                ErrorMessage = '*must include both collection and project*'
            }
            @{
                Scenario = 'a query/fragment combination that still does not identify a project resource'
                Action = {
                    Resolve-GerberAdoProjectUrl -Url 'https://dev.azure.com/myorganization/MyProject/unknown?path=/src#frag'
                }
                ErrorMessage = '*does not identify a supported project resource*'
            }
        ) {
            { & $Action } | Should -Throw $ErrorMessage
        }
    }

    Context 'behavior' {
        It 'is deterministic for the same input' {
            $first = Resolve-GerberAdoProjectUrl -Url 'https://ado.example.test/tfs/DefaultCollection/My%20Project'
            $second = Resolve-GerberAdoProjectUrl -Url 'https://ado.example.test/tfs/DefaultCollection/My%20Project'

            $first | ConvertTo-Json -Depth 5 | Should -Be ($second | ConvertTo-Json -Depth 5)
        }

        It 'does not perform network, filesystem, prompting, or credential-store initialization side effects' {
            Mock Invoke-RestMethod { throw 'Invoke-RestMethod should not be called.' }
            Mock Invoke-WebRequest { throw 'Invoke-WebRequest should not be called.' }
            Mock Get-Credential { throw 'Get-Credential should not be called.' }
            Mock New-Item { throw 'New-Item should not be called.' }
            Mock Set-Content { throw 'Set-Content should not be called.' }
            Mock Get-GerberCredentialStore { throw 'Credential storage should not be initialized.' }

            $result = Resolve-GerberAdoProjectUrl -Url 'https://dev.azure.com/myorganization/MyProject/_git/MyRepository?path=/src'

            $result.Project | Should -Be 'MyProject'
            Should -Invoke Invoke-RestMethod -Times 0
            Should -Invoke Invoke-WebRequest -Times 0
            Should -Invoke Get-Credential -Times 0
            Should -Invoke New-Item -Times 0
            Should -Invoke Set-Content -Times 0
            Should -Invoke Get-GerberCredentialStore -Times 0
        }
    }
}
