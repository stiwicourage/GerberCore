function Get-GerberAdoEnvironmentList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat
    )

    $uri = Get-GerberAdoEnvironmentListUri -Configuration $Configuration
    $response = Invoke-GerberAdoRestRequest `
        -Uri $uri `
        -Pat $Pat `
        -RequestLabel 'release environments' `
        -CredentialIdentifier $Configuration.CredentialIdentifier

    return @(
        Get-GerberAdoResponseValueList -Response $response |
            ForEach-Object { ConvertTo-GerberAdoEnvironmentItem -Environment $_ }
    )
}

function Get-GerberAdoEnvironmentListUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration
    )

    return Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($Configuration.CollectionUri, "$($Configuration.ProjectName)/_apis/pipelines/environments")) `
        -QueryParameterMap @{ 'api-version' = '7.2-preview.1' }
}

function ConvertTo-GerberAdoEnvironmentItem {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Environment
    )

    return [pscustomobject]@{
        Id   = [int]$Environment.id
        Name = [string]$Environment.name
    }
}
