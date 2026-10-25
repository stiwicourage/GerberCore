function Get-GerberAdoTeamMemberReport {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param()

    $configuration = Get-GerberAdoConfiguration
    $pat = Resolve-GerberAdoPat -Configuration $configuration
    $projectList = @(Get-GerberAdoResolvedProjectList -Configuration $configuration -Pat $pat)
    return [pscustomobject]@{
        Configuration = $configuration
        ProjectList = $projectList
    }
}

function Get-GerberAdoResolvedProjectList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat
    )

    return @(
        foreach ($project in @(Get-GerberAdoProjectList -Configuration $Configuration -Pat $Pat)) {
            [pscustomobject]@{
                Id = $project.Id
                Name = $project.Name
                TeamList = @(Get-GerberAdoResolvedTeamList -Configuration $Configuration -Pat $Pat -ProjectId $project.Id)
            }
        }
    )
}

function Get-GerberAdoResolvedTeamList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [string]$ProjectId
    )

    return @(
        foreach ($team in @(Get-GerberAdoTeamList -Configuration $Configuration -Pat $Pat -ProjectId $ProjectId)) {
            [pscustomobject]@{
                Id = $team.Id
                Name = $team.Name
                MemberList = @(Get-GerberAdoTeamMemberList `
                    -Configuration $Configuration `
                    -Pat $Pat `
                    -ProjectId $ProjectId `
                    -TeamId $team.Id)
            }
        }
    )
}

function Get-GerberAdoProjectList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat
    )

    Get-GerberAdoNamedItemList -Configuration $Configuration -Pat $Pat `
        -RelativePath '_apis/projects' -RequestLabel 'projects'
}

function Get-GerberAdoTeamList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [string]$ProjectId
    )

    $requestParams = @{
        Configuration = $Configuration
        Pat           = $Pat
        RelativePath  = "_apis/projects/$ProjectId/teams"
        RequestLabel  = "teams for project $ProjectId"
    }
    Get-GerberAdoNamedItemList @requestParams
}

function Get-GerberAdoTeamMemberList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [string]$ProjectId,

        [Parameter(Mandatory)]
        [string]$TeamId
    )

    $memberPath = "_apis/projects/$ProjectId/teams/$TeamId/members"
    $uri = Get-GerberAdoTeamMemberRequestUri -Configuration $Configuration -RelativePath $memberPath
    $response = Invoke-GerberAdoRestRequest -Uri $uri -Pat $Pat `
        -RequestLabel "members of team $TeamId" `
        -CredentialIdentifier $Configuration.CredentialIdentifier
    $memberItems = @(Get-GerberAdoResponseValueList -Response $response)
    $mapped = foreach ($member in $memberItems) {
        $identity = Get-GerberAdoMemberIdentity -Item $member
        [pscustomobject]@{ DisplayName = [string]$identity.displayName; UniqueName = [string]$identity.uniqueName }
    }
    $mapped | Sort-Object -Property DisplayName
}

function Get-GerberAdoNamedItemList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [string]$RelativePath,

        [Parameter(Mandatory)]
        [string]$RequestLabel
    )

    $uri = Get-GerberAdoTeamMemberRequestUri -Configuration $Configuration -RelativePath $RelativePath
    $response = Invoke-GerberAdoRestRequest `
        -Uri $uri `
        -Pat $Pat `
        -RequestLabel $RequestLabel `
        -CredentialIdentifier $Configuration.CredentialIdentifier
    Get-GerberAdoResponseValueList -Response $response |
        ForEach-Object { [pscustomobject]@{ Id = [string]$_.id; Name = [string]$_.name } } |
        Sort-Object -Property Name
}

function Get-GerberAdoMemberIdentity {
    [OutputType([object])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Item
    )

    if ($Item.PSObject.Properties.Match('identity').Count -gt 0) {
        return $Item.identity
    }
    return $Item
}

function Get-GerberAdoTeamMemberRequestUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    return Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($Configuration.CollectionUri, $RelativePath)) `
        -QueryParameterMap ([ordered]@{
            'api-version' = $Configuration.DefaultApiVersion
        })
}
