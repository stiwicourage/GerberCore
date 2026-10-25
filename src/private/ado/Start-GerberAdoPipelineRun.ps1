function Start-GerberAdoPipelineRun {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$RunRequest
    )

    $configuration = $RunRequest.Configuration
    $pat = $RunRequest.Pat
    $definitionId = $RunRequest.DefinitionId
    $branchName = $RunRequest.BranchName
    $fixversion = $RunRequest.Fixversion

    $null = $PSCmdlet.ShouldProcess("pipeline definition $DefinitionId", 'start Azure DevOps pipeline run')
    $normalizedBranchName = Get-GerberAdoBuildSourceBranch -BranchName $branchName
    $queueUri = Get-GerberAdoBuildQueueUri -Configuration $configuration
    $templateParameterMap = Get-GerberAdoBuildTemplateParameterMap -RunRequest $RunRequest
    $queuedBuild = Invoke-GerberAdoBuildQueueRequest -QueueRequest ([pscustomobject]@{
            QueueUri      = $queueUri
            Configuration = $configuration
            Pat           = $pat
            DefinitionId  = $definitionId
            SourceBranch  = $normalizedBranchName
            TemplateParameterMap = $templateParameterMap
        })

    $buildId = Get-GerberAdoQueuedBuildId -QueuedBuild $queuedBuild -DefinitionId $definitionId
    Add-GerberAdoBuildTag `
        -Configuration $configuration `
        -Pat $pat `
        -BuildId $buildId `
        -Tag $fixversion
    Add-GerberAdoBuildCarryoverTagList `
        -Configuration $configuration `
        -Pat $pat `
        -BuildId $buildId `
        -RunRequest $RunRequest

    return [pscustomobject]@{
        DefinitionId = $definitionId
        BuildId      = $buildId
        SourceBranch = $normalizedBranchName
        RunUrl       = Get-GerberAdoBuildRunUrl -Configuration $configuration -BuildId $buildId
    }
}

function Get-GerberAdoBuildSourceBranch {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BranchName
    )

    if ($BranchName.StartsWith('refs/heads/', [System.StringComparison]::OrdinalIgnoreCase)) {
        return $BranchName
    }

    return "refs/heads/$BranchName"
}

function Get-GerberAdoBuildQueueUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration
    )

    return Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($Configuration.CollectionUri, "$($Configuration.ProjectName)/_apis/build/builds")) `
        -QueryParameterMap @{ 'api-version' = '7.1' }
}

function Invoke-GerberAdoBuildQueueRequest {
    [OutputType([object])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$QueueRequest
    )

    $queueUri = $QueueRequest.QueueUri
    $configuration = $QueueRequest.Configuration
    $pat = $QueueRequest.Pat
    $definitionId = $QueueRequest.DefinitionId
    $sourceBranch = $QueueRequest.SourceBranch
    $httpConfig = Get-GerberHttpConfiguration
    $bodyData = @{
        definition   = @{ id = $definitionId }
        sourceBranch = $sourceBranch
    }
    $templateParameterMap = Get-GerberAdoBuildTemplateParameterMap -RunRequest $QueueRequest
    Add-GerberAdoBuildTemplateParameterMap -BodyData $bodyData -TemplateParameterMap $templateParameterMap
    $body = $bodyData | ConvertTo-Json -Depth 10

    try {
        return Invoke-RestMethod `
            -Method Post `
            -Uri $queueUri `
            -ConnectionTimeoutSeconds $httpConfig.ConnectionTimeoutSeconds `
            -OperationTimeoutSeconds $httpConfig.OperationTimeoutSeconds `
            -Headers (Get-GerberAdoJsonRequestHeader -Pat $pat) `
            -Body $body `
            -ErrorAction Stop
    } catch {
        throw [System.ArgumentException]::new(
            (Get-GerberAdoMutationFailureMessage `
            -Uri $queueUri `
            -RequestLabel "queue pipeline definition $definitionId" `
            -CredentialIdentifier $configuration.CredentialIdentifier `
            -Exception $_.Exception),
            $_.Exception
        )
    }
}

function Get-GerberAdoBuildTemplateParameterMap {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$RunRequest
    )

    if ($RunRequest.PSObject.Properties.Name -notcontains 'TemplateParameterMap') {
        return @{}
    }

    $templateParameterMap = $RunRequest.TemplateParameterMap
    if ($templateParameterMap -isnot [hashtable] -or $templateParameterMap.Count -eq 0) {
        return @{}
    }

    return $templateParameterMap
}

function Add-GerberAdoBuildTemplateParameterMap {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [hashtable]$BodyData,

        [Parameter(Mandatory)]
        [hashtable]$TemplateParameterMap
    )

    if ($TemplateParameterMap.Count -eq 0) {
        return
    }

    $null = $PSCmdlet.ShouldProcess('build queue body', 'add template parameters')
    $BodyData['templateParameters'] = $TemplateParameterMap
}

function Add-GerberAdoBuildCarryoverTagList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [int]$BuildId,

        [Parameter(Mandatory)]
        [pscustomobject]$RunRequest
    )

    $carryoverTagList = @(Get-GerberAdoBuildCarryoverTagList -RunRequest $RunRequest)
    if ($carryoverTagList.Count -eq 0) {
        return
    }

    $currentTagSet = Get-GerberAdoBuildTagSet `
        -Configuration $Configuration `
        -Pat $Pat `
        -BuildId $BuildId
    foreach ($tag in $carryoverTagList) {
        if (-not $currentTagSet.Add($tag)) {
            continue
        }

        Add-GerberAdoBuildTag `
            -Configuration $Configuration `
            -Pat $Pat `
            -BuildId $BuildId `
            -Tag $tag
    }
}

function Get-GerberAdoBuildCarryoverTagList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$RunRequest
    )

    if ($RunRequest.PSObject.Properties.Name -notcontains 'CarryoverTagList') {
        return [string[]]@()
    }

    return [string[]]@(
        foreach ($tag in @($RunRequest.CarryoverTagList)) {
            if ([string]::IsNullOrWhiteSpace([string]$tag)) {
                continue
            }

            [string]$tag
        }
    )
}

function Get-GerberAdoBuildTagUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [int]$BuildId,

        [Parameter(Mandatory)]
        [string]$Tag
    )

    return Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($Configuration.CollectionUri, "$($Configuration.ProjectName)/_apis/build/builds/$BuildId/tags/$([uri]::EscapeDataString($Tag))")) `
        -QueryParameterMap @{ 'api-version' = '7.1' }
}

function Get-GerberAdoQueuedBuildId {
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$QueuedBuild,

        [Parameter(Mandatory)]
        [int]$DefinitionId
    )

    $buildId = if (($QueuedBuild -is [hashtable]) -and $QueuedBuild.ContainsKey('id')) {
        [int]$QueuedBuild.id
    } elseif (($null -ne $QueuedBuild) -and ($QueuedBuild.PSObject.Properties.Match('id').Count -gt 0)) {
        [int]$QueuedBuild.id
    } else {
        0
    }

    if ($buildId -le 0) {
        throw [System.ArgumentException]::new(
            "Gerber queued pipeline definition '$DefinitionId' but did not receive a build ID back from Azure DevOps."
        )
    }

    return $buildId
}

function Get-GerberAdoBuildRunUrl {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [int]$BuildId
    )

    return ([System.Uri]::new($Configuration.CollectionUri, "$($Configuration.ProjectName)/_build/results?buildId=$BuildId&view=results")).AbsoluteUri
}

function Get-GerberAdoJsonRequestHeader {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Pat
    )

    $header = Get-GerberAdoRequestHeader -Pat $Pat
    $header.Accept = 'application/json'
    $header.'Content-Type' = 'application/json'
    return $header
}

function Get-GerberAdoMutationFailureMessage {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$Uri,

        [Parameter(Mandatory)]
        [string]$RequestLabel,

        [Parameter(Mandatory)]
        [Alias('CredentialIdentifier')]
        [string]$PatAccountIdentifier,

        [AllowNull()]
        [System.Exception]$Exception
    )

    if (Test-GerberAdoUnauthorizedFailure -Exception $Exception) {
        return "Gerber could not update Azure DevOps to $RequestLabel. Update PAT credential '$PatAccountIdentifier' with /secrets set, then try again."
    }

    $transportHint = Get-GerberHttpTransportFailureHint -Exception $Exception
    if (-not [string]::IsNullOrWhiteSpace($transportHint)) {
        return "Gerber could not reach Azure DevOps at '$Uri'. $transportHint"
    }

    $reason = if ($null -eq $Exception -or [string]::IsNullOrWhiteSpace($Exception.Message)) {
        'Try again in a moment.'
    } else {
        $Exception.Message
    }

    return "Gerber could not update Azure DevOps to $RequestLabel at '$Uri'. $reason"
}
