function Get-GerberAdoPullRequestFileContent {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [pscustomobject]$PullRequest,

        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$AllowMissing
    )

    $uri = Get-GerberAdoPullRequestFileContentUri -Context $Context -PullRequest $PullRequest -Path $Path
    $requestHeaders = Get-GerberAdoRequestHeader -Pat $Context.Pat
    $httpConfig = Get-GerberHttpConfiguration
    try {
        $response = Invoke-WebRequest `
            -Uri $uri `
            -Headers $requestHeaders `
            -UseBasicParsing `
            -ConnectionTimeoutSeconds $httpConfig.ConnectionTimeoutSeconds `
            -OperationTimeoutSeconds $httpConfig.OperationTimeoutSeconds `
            -ErrorAction Stop
    } catch {
        $statusCode = Get-GerberAdoHttpStatusCode -Exception $_.Exception
        if ($AllowMissing -and ($statusCode -eq 404)) {
            return $null
        }

        throw [System.ArgumentException]::new(
            (Get-GerberAdoRequestFailureMessage `
                -Uri $uri `
                -RequestLabel "content for '$Path' in pull request $($PullRequest.PullRequestId)" `
                -CredentialIdentifier $Context.Configuration.CredentialIdentifier `
                -Exception $_.Exception),
            $_.Exception
        )
    }

    if ($response.Content -is [byte[]]) {
        return Get-GerberTextWithoutLeadingUtf8Bom -Text ([System.Text.Encoding]::UTF8.GetString($response.Content))
    }

    return Get-GerberTextWithoutLeadingUtf8Bom -Text ([string]$response.Content)
}

function Get-GerberAdoPullRequestFileContentUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [pscustomobject]$PullRequest,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $relativePath = "$($PullRequest.ProjectName)/_apis/git/repositories/$($PullRequest.RepositoryId)/items"
    return Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($Context.Configuration.CollectionUri, $relativePath)) `
        -QueryParameterMap ([ordered]@{
            'api-version' = $Context.Configuration.DefaultApiVersion
            'path' = $Path
            'includeContent' = 'true'
            'versionDescriptor.versionType' = 'commit'
            'versionDescriptor.version' = $PullRequest.SourceCommitId
        })
}

function Get-GerberTextWithoutLeadingUtf8Bom {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Text
    )

    if ($null -eq $Text) {
        return $null
    }

    return $Text.TrimStart([char]0xFEFF)
}
