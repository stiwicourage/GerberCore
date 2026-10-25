function Get-GerberAdoRepositoryItemTree {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [string]$RepoId,

        [string]$BranchName
    )

    try {
        $projectScope = Resolve-GerberAdoProjectScope -Context $Context
        $relPath = "$projectScope/_apis/git/repositories/$RepoId/items"
        $uri = Get-GerberAdoItemListUri -Context $Context -RelPath $relPath -BranchName $BranchName
        $response = Invoke-GerberAdoRestRequest `
            -Uri $uri `
            -Pat $Context.Pat `
            -RequestLabel "item tree for repository $RepoId" `
            -CredentialIdentifier $Context.Configuration.CredentialIdentifier
        $items = Get-GerberAdoResponseValueList -Response $response
        Write-Verbose "Fetched $($items.Count) items from repository $RepoId"
        $requestHeaders = Get-GerberAdoRequestHeader -Pat $Context.Pat
        $fileTree = Build-GerberAdoFileTree -Context $Context -RelPath $relPath -Items $items -RequestHeaders $requestHeaders
        Write-Verbose "Fetched content for $($fileTree.Count) blobs"
        return [pscustomobject]@{
            Success  = $true
            FileTree = $fileTree
        }
    } catch {
        return [pscustomobject]@{
            Success     = $false
            FileTree    = @()
            ErrorDetail = $_.Exception.Message
        }
    }
}

function Get-GerberAdoItemListUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [string]$RelPath,

        [AllowEmptyString()]
        [string]$BranchName
    )

    $query = [ordered]@{
        'api-version'    = $Context.Configuration.DefaultApiVersion
        'recursionLevel' = 'Full'
    }
    if (-not [string]::IsNullOrEmpty($BranchName)) {
        $query['versionDescriptor.version']     = $BranchName
        $query['versionDescriptor.versionType'] = 'branch'
    }
    return Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($Context.Configuration.CollectionUri, $RelPath)) `
        -QueryParameterMap $query
}

# Fetch content for a single blob using Invoke-WebRequest so the raw response
# body is always returned as a string. Invoke-RestMethod would automatically
# deserialize XML files (e.g. .csproj) into XmlDocument, which cannot be
# cast to a meaningful string.
# The ADO Items API may omit a charset in the Content-Type header, which
# causes Invoke-WebRequest to expose the body as byte[] instead of string.
# Decode byte[] as UTF-8 so all file types are handled uniformly.
function Get-GerberAdoBlobContent {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [string]$RelPath,

        [Parameter(Mandatory)]
        [string]$ItemPath,

        [Parameter(Mandatory)]
        [hashtable]$RequestHeaders
    )

    $contentUri = Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($Context.Configuration.CollectionUri, $RelPath)) `
        -QueryParameterMap ([ordered]@{
            'api-version'    = $Context.Configuration.DefaultApiVersion
            'path'           = $ItemPath
            'includeContent' = 'true'
        })
    $contentResponse = Invoke-WebRequest `
        -Uri $contentUri `
        -Headers $RequestHeaders `
        -UseBasicParsing `
        -ErrorAction Stop
    $rawContent = $contentResponse.Content
    if ($rawContent -is [byte[]]) {
        return [System.Text.Encoding]::UTF8.GetString($rawContent)
    }
    return [string]$rawContent
}

function Build-GerberAdoFileTree {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [string]$RelPath,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Items,

        [Parameter(Mandatory)]
        [hashtable]$RequestHeaders
    )

    return @(
        foreach ($item in $Items) {
            if ($item.gitObjectType -eq 'blob') {
                $contentString = Get-GerberAdoBlobContent `
                    -Context $Context `
                    -RelPath $RelPath `
                    -ItemPath $item.path `
                    -RequestHeaders $RequestHeaders
                [pscustomobject]@{
                    path          = $item.path
                    gitObjectType = $item.gitObjectType
                    content       = $contentString
                }
            }
        }
    )
}
