function Get-GerberAdoAgentReport {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param()

    Write-GerberScreenLine -Text 'Connecting to Azure DevOps...'
    $configuration = Get-GerberAdoConfiguration
    $pat = Resolve-GerberAdoPat -Configuration $configuration
    $sectionList = @(
        Get-GerberAdoAgentSection -Configuration $configuration -Pat $pat -SectionName 'BUILD' -PoolType 'automation'
        Get-GerberAdoAgentSection -Configuration $configuration -Pat $pat -SectionName 'DEPLOY' -PoolType 'deployment'
    )

    return [pscustomobject]@{
        Configuration = $configuration
        Sections = $sectionList
        VersionList = Get-GerberAdoVersionList -SectionList $sectionList
    }
}

function Get-GerberAdoAgentSection {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [string]$SectionName,

        [Parameter(Mandatory)]
        [string]$PoolType
    )

    $poolList = @(Get-GerberAdoPoolList -Configuration $Configuration -Pat $Pat -PoolType $PoolType)
    $sortedPoolList = @($poolList | Sort-Object -Property @{ Expression = { $_.Name.ToLowerInvariant() } }, Name)
    $resolvedPoolList = @(
        foreach ($pool in $sortedPoolList) {
            $agentList = @(Get-GerberAdoPoolAgentList -Configuration $Configuration -Pat $Pat -Pool $pool)
            [pscustomobject]@{
                Id = $pool.Id
                Name = $pool.Name
                AgentList = @($agentList | Sort-Object -Property @{ Expression = { $_.Name.ToLowerInvariant() } }, Name)
            }
        }
    )

    return [pscustomobject]@{
        Name = $SectionName
        PoolType = $PoolType
        PoolList = $resolvedPoolList
    }
}

function Get-GerberAdoPoolList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [string]$PoolType
    )

    return Get-GerberAdoPoolResourceList `
        -Configuration $Configuration `
        -Pat $Pat `
    -RequestContext ([pscustomobject]@{
        Uri = Get-GerberAdoPoolResourceUri `
            -Configuration $Configuration `
            -RelativePath '_apis/distributedtask/pools' `
            -QueryParameterMap ([ordered]@{
                poolType = $PoolType
            })
        Label = "$PoolType pools"
        Converter = {
            param($pool)

            [pscustomobject]@{
                Id = [int]$pool.id
                Name = [string]$pool.name
            }
        }
    })
}

function Get-GerberAdoPoolAgentList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [pscustomobject]$Pool
    )

    return Get-GerberAdoPoolResourceList `
        -Configuration $Configuration `
        -Pat $Pat `
    -RequestContext ([pscustomobject]@{
        Uri = Get-GerberAdoPoolResourceUri `
            -Configuration $Configuration `
            -RelativePath "_apis/distributedtask/pools/$($Pool.Id)/agents" `
            -QueryParameterMap ([ordered]@{
                includeCapabilities = 'false'
            })
        Label = "agents for pool '$($Pool.Name)'"
        Converter = {
            param($agent)

            [pscustomobject]@{
                Name = [string]$agent.name
                Version = Get-GerberAdoAgentPropertyText -Agent $agent -PropertyName 'version'
                Status = Get-GerberAdoAgentPropertyText -Agent $agent -PropertyName 'status'
            }
        }
    })
}

function Get-GerberAdoPoolResourceList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [pscustomobject]$RequestContext
    )

    $response = Invoke-GerberAdoRestRequest `
        -Uri $RequestContext.Uri `
        -Pat $Pat `
        -RequestLabel $RequestContext.Label `
        -CredentialIdentifier $Configuration.CredentialIdentifier

    return @(
        foreach ($item in @(Get-GerberAdoResponseValueList -Response $response)) {
            & $RequestContext.Converter $item
        }
    )
}

function Get-GerberAdoPoolResourceUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$RelativePath,

        [Parameter(Mandatory)]
        [hashtable]$QueryParameterMap
    )

    $resolvedQueryParameterMap = [ordered]@{}
    foreach ($name in $QueryParameterMap.Keys) {
        $resolvedQueryParameterMap[$name] = $QueryParameterMap[$name]
    }

    $resolvedQueryParameterMap['api-version'] = $Configuration.PoolApiVersion
    return Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($Configuration.CollectionUri, $RelativePath)) `
        -QueryParameterMap $resolvedQueryParameterMap
}

function Get-GerberAdoAgentPropertyText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Agent,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    $value = [string]$Agent.$PropertyName
    if ([string]::IsNullOrWhiteSpace($value)) {
        return 'unknown'
    }

    return $value.Trim()
}

function Get-GerberAdoVersionList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject[]]$SectionList
    )

    $versionSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($section in $SectionList) {
        foreach ($pool in @($section.PoolList)) {
            foreach ($agent in @($pool.AgentList)) {
                $null = $versionSet.Add($agent.Version)
            }
        }
    }

    return @($versionSet | Sort-Object)
}
