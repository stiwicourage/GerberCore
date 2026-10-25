function New-GerberAdoPolicyConfiguration {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [string]$RepoId,

        [Parameter(Mandatory)]
        [pscustomobject]$Policy,

        [Parameter(Mandatory)]
        [string]$TeamId
    )
    $null = $PSCmdlet.ShouldProcess('New-GerberAdoPolicyConfiguration', 'Invoke')

    try {
        $projectScope = Resolve-GerberAdoProjectScope -Context $Context
        $relPath = "$projectScope/_apis/policy/configurations"
        $uri = Get-GerberAdoBranchRequestUri -Configuration $Context.Configuration -RelativePath $relPath
        $body = Build-GerberAdoPolicyBody -Policy $Policy -RepoId $RepoId -TeamId $TeamId
        $mutationContext = [pscustomobject]@{
            Uri = $uri; Pat = $Context.Pat; Method = 'Post'; Body = $body
            RequestLabel = "policy for repository $RepoId"
            CredentialIdentifier = $Context.Configuration.CredentialIdentifier
        }
        $null = Invoke-GerberAdoRestMutation -MutationContext $mutationContext
        return [pscustomobject]@{ Success = $true }
    } catch {
        return [pscustomobject]@{ Success = $false; ErrorDetail = $_.Exception.Message }
    }
}

function Build-GerberAdoPolicyBody {
    [OutputType([string])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Policy,

        [Parameter(Mandatory)]
        [string]$RepoId,

        [Parameter(Mandatory)]
        [string]$TeamId
    )
    $null = $PSCmdlet.ShouldProcess('Build-GerberAdoPolicyBody', 'Invoke')

    $settings = $Policy.Settings | ConvertTo-Json -Depth 10 | ConvertFrom-Json -AsHashtable
    $settings.scope = @($settings.scope | ForEach-Object {
        @{
            repositoryId = $RepoId
            refName = $_.refName
            matchKind = $_.matchKind
        }
    })
    if ($Policy.Type.id -eq 'fd2167ab-b0be-447a-8ec8-39368250530e') {
        $settings.requiredReviewerIds = @($TeamId)
    }
    return ConvertTo-Json -InputObject @{
        isEnabled = $true
        isBlocking = $true
        type = $Policy.Type
        settings = $settings
    } -Depth 10 -Compress
}
