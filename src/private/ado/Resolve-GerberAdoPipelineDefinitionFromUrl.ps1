function Resolve-GerberAdoPipelineDefinitionFromUrl {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [uri]$PipelineUrl
    )

    $definitionId = Get-GerberAdoBuildDefinitionId -PipelineUrl $PipelineUrl
    $uri = Get-GerberAdoBuildDefinitionUri -Configuration $Configuration -DefinitionId $definitionId
    $response = Invoke-GerberAdoRestRequest `
        -Uri $uri `
        -Pat $Pat `
        -RequestLabel "pipeline definition $definitionId" `
        -CredentialIdentifier $Configuration.CredentialIdentifier

    return ConvertTo-GerberResolvedBuildDefinition -Response $response -PipelineUrl $PipelineUrl -DefinitionId $definitionId
}

function Get-GerberAdoBuildDefinitionId {
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$PipelineUrl
    )

    $definitionId = $null
    foreach ($queryPart in @($PipelineUrl.Query.TrimStart('?') -split '&')) {
        if ($queryPart -notmatch '^(?i)definitionId=(?<value>\d+)$') {
            continue
        }

        $definitionId = [int]$Matches['value']
        break
    }

    if ($null -eq $definitionId) {
        throw [System.ArgumentException]::new(
            "Gerber could not read an Azure DevOps pipeline definition ID from '$PipelineUrl'."
        )
    }

    return $definitionId
}

function Get-GerberAdoBuildDefinitionUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [int]$DefinitionId
    )

    return Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($Configuration.CollectionUri, "$($Configuration.ProjectName)/_apis/build/definitions/$DefinitionId")) `
        -QueryParameterMap @{ 'api-version' = '7.1' }
}

function ConvertTo-GerberResolvedBuildDefinition {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Response,

        [Parameter(Mandatory)]
        [uri]$PipelineUrl,

        [Parameter(Mandatory)]
        [int]$DefinitionId
    )

    $name = Get-GerberResolvedBuildDefinitionPropertyValue -Response $Response -PropertyName 'name'
    if ([string]::IsNullOrWhiteSpace($name)) {
        throw [System.ArgumentException]::new(
            "Gerber could not read the Azure DevOps pipeline definition name for '$PipelineUrl'."
        )
    }

    return [pscustomobject]@{
        Id   = $DefinitionId
        Name = $name
        Url  = $PipelineUrl
    }
}

function Get-GerberResolvedBuildDefinitionPropertyValue {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Response,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    if ($null -eq $Response) {
        return ''
    }

    if (($Response -is [hashtable]) -and $Response.ContainsKey($PropertyName)) {
        return [string]$Response[$PropertyName]
    }

    if ($Response.PSObject.Properties.Match($PropertyName).Count -eq 0) {
        return ''
    }

    return [string]$Response.$PropertyName
}
