function Get-TestGerberPluginApiAdoConfiguration {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param()

    return [pscustomobject]@{
        ProfileName          = 'EXAMPLE'
        DeploymentType       = 'Services'
        Organization         = 'example-org'
        Collection           = ''
        CollectionUri        = [uri]'https://dev.azure.com/example-org/'
        CollectionName       = 'example-org'
        ProjectName          = 'SampleProject'
        ProjectUri           = [uri]'https://dev.azure.com/example-org/SampleProject'
        DefaultApiVersion    = '7.0'
        CredentialIdentifier = 'gerber:ado:EXAMPLE:pat'
        ServerUrl            = [uri]'https://dev.azure.com'
        ServerUri            = [uri]'https://dev.azure.com'
    }
}

function Get-TestGerberPluginApiAdoConnection {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [string]$CommandLabel = '/repository review',
        [string]$ProfileName = 'EXAMPLE',
        [string]$ProjectName = 'SampleProject',
        [string]$Organization = 'example-org'
    )

    return [pscustomobject][ordered]@{
        Id             = 'connection-1'
        CommandLabel   = $CommandLabel
        ProfileName    = $ProfileName
        DeploymentType = 'Services'
        ServerUri      = [uri]'https://dev.azure.com'
        Organization   = $Organization
        Collection     = ''
        CollectionName = $Organization
        CollectionUri  = [uri]"https://dev.azure.com/$Organization/"
        ProjectName    = $ProjectName
        ProjectUri     = [uri]"https://dev.azure.com/$Organization/$ProjectName"
    }
}

function Assert-TestGerberPluginApiPullRequestOperationSet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Outcome
    )

    Assert-TestGerberPluginApiPullRequestOutcome -Outcome $Outcome
    Assert-TestGerberPluginApiConfigurationInvocation `
        -CommandName 'Resolve-GerberAdoPullRequestReference' `
        -AdditionalFilter {
            $InputText -eq '18075' -and
            $Configuration.ProjectName -eq 'SampleProject'
        }
    Assert-TestGerberPluginApiConfigurationInvocation `
        -CommandName 'Get-GerberAdoPullRequest' `
        -AdditionalFilter {
            $Pat -eq 'resolved-pat' -and
            $Configuration.ProjectName -eq 'SampleProject' -and
            $PullRequestReference.PullRequestId -eq 18075
        }
    Assert-TestGerberPluginApiRequestContextInvocation `
        -CommandName 'Get-GerberAdoPullRequestChangedFileList' `
        -AdditionalFilter {
            $PullRequest.PullRequestId -eq 18075
        }
    Assert-TestGerberPluginApiRequestContextInvocation `
        -CommandName 'Get-GerberAdoPullRequestFileContent' `
        -AdditionalFilter {
            $Path -eq '/azure-pipelines.yml' -and
            $AllowMissing
        }
    Assert-TestGerberPluginApiRequestContextInvocation `
        -CommandName 'Get-GerberAdoPullRequestBuildValidationStatus' `
        -AdditionalFilter {
            $PullRequest.PullRequestId -eq 18075
        }
}

function Assert-TestGerberPluginApiPullRequestOutcome {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Outcome
    )

    $Outcome.Reference.PullRequestId | Should -Be 18075
    $Outcome.PullRequest.RepositoryName | Should -Be 'Repo'
    $Outcome.ChangedFileList[0].Path | Should -Be '/azure-pipelines.yml'
    $Outcome.Content | Should -Be 'trigger: none'
    $Outcome.BuildValidation.IsAvailable | Should -BeTrue
}

function Assert-TestGerberPluginApiConfigurationInvocation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName,

        [Parameter(Mandatory)]
        [scriptblock]$AdditionalFilter
    )

    $filter = $AdditionalFilter
    Should -Invoke $CommandName -Times 1 -ParameterFilter {
        & $filter
    }
}

function Assert-TestGerberPluginApiRequestContextInvocation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName,

        [Parameter(Mandatory)]
        [scriptblock]$AdditionalFilter
    )

    $filter = $AdditionalFilter
    Should -Invoke $CommandName -Times 1 -ParameterFilter {
        $Context.Pat -eq 'resolved-pat' -and
        $Context.Configuration.ProjectName -eq 'SampleProject' -and
        (& $filter)
    }
}
