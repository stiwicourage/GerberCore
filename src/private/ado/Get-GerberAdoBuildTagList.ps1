function Get-GerberAdoBuildTagList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [int]$BuildId
    )

    $response = Invoke-GerberAdoRestRequest `
        -Uri (Get-GerberAdoBuildTagListUri -Configuration $Configuration -BuildId $BuildId) `
        -Pat $Pat `
        -RequestLabel "tags for build $BuildId" `
        -CredentialIdentifier $Configuration.CredentialIdentifier

    return [string[]]@(
        Get-GerberAdoResponseValueList -Response $response |
            ForEach-Object { ConvertTo-GerberAdoBuildTagText -Tag $_ }
    )
}

function Get-GerberAdoBuildTagListUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [int]$BuildId
    )

    return Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($Configuration.CollectionUri, "$($Configuration.ProjectName)/_apis/build/builds/$BuildId/tags")) `
        -QueryParameterMap @{ 'api-version' = '7.1' }
}

function ConvertTo-GerberAdoBuildTagText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Tag
    )

    return ([string]$Tag).Trim()
}
