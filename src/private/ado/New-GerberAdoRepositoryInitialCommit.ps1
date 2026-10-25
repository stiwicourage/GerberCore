function New-GerberAdoRepositoryInitialCommit {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [string]$RepoId,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$FileTree,

        [Parameter(Mandatory)]
        [string]$DefaultBranchRef
    )
    $null = $PSCmdlet.ShouldProcess('New-GerberAdoRepositoryInitialCommit', 'Invoke')

    try {
        $changes = @(Get-GerberAdoCommitChangeList -FileTree $FileTree -RepositoryName $Context.RepositoryName)
        if ($changes.Count -eq 0) {
            return [pscustomobject]@{
                Success = $false
                ErrorDetail = "No files to commit (FileTree had $($FileTree.Count) items)"
            }
        }
        Write-Verbose "Initial commit: Creating commit with $($changes.Count) file(s)"
        $projectScope = Resolve-GerberAdoProjectScope -Context $Context
        $relPath = "$projectScope/_apis/git/repositories/$RepoId/pushes"
        $uri = Get-GerberAdoApiUri `
            -BaseUri ([System.Uri]::new($Context.Configuration.CollectionUri, $relPath)) `
            -QueryParameterMap ([ordered]@{ 'api-version' = $Context.Configuration.DefaultApiVersion })
        $body = ConvertTo-Json -InputObject @{
            refUpdates = @(@{
                name = $DefaultBranchRef
                oldObjectId = '0000000000000000000000000000000000000000'
            })
            commits = @(@{
                comment = 'Initial commit'
                changes = $changes
            })
        } -Depth 10 -Compress
        $headers = @{
            'Authorization' = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($Context.Pat)")))"
            'Content-Type' = 'application/json'
        }
        Write-Verbose "Initial commit: POST $uri"
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body -ErrorAction Stop
        Write-Verbose "Initial commit: Push ID $($response.pushId) created"
        return [pscustomobject]@{ Success = $true }
    } catch {
        return [pscustomobject]@{
            Success = $false
            ErrorDetail = $_.Exception.Message
        }
    }
}

function Get-GerberAdoCommitChangeList {
    [OutputType([object[]])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$FileTree,

        [Parameter(Mandatory)]
        [string]$RepositoryName
    )
    $null = $PSCmdlet.ShouldProcess('Get-GerberAdoCommitChangeList', 'Invoke')

    return @(
        foreach ($item in $FileTree) {
            if ($item.gitObjectType -eq 'blob') {
                @{
                    changeType = 'add'
                    item = @{ path = (Resolve-GerberLegacyPackageNamePlaceholder -Text $item.path -RepositoryName $RepositoryName) }
                    newContent = @{
                        content = (Resolve-GerberLegacyPackageNamePlaceholder -Text $item.content -RepositoryName $RepositoryName)
                        contentType = 'rawtext'
                    }
                }
            }
        }
    )
}

function Resolve-GerberLegacyPackageNamePlaceholder {
    [OutputType([string])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory)]
        [string]$RepositoryName
    )
    $null = $PSCmdlet.ShouldProcess('Resolve-GerberLegacyPackageNamePlaceholder', 'Invoke')

    return $Text -replace 'PackageName', $RepositoryName
}
