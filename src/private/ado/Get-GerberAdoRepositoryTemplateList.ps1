function Get-GerberAdoRepositoryTemplateList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [string]$ProjectName
    )

    $relPath = "$ProjectName/_apis/git/repositories"
    $uri = Get-GerberAdoBranchRequestUri -Configuration $Configuration -RelativePath $relPath
    $response = Invoke-GerberAdoRestRequest `
        -Uri $uri `
        -Pat $Pat `
        -RequestLabel 'template repositories' `
        -CredentialIdentifier $Configuration.CredentialIdentifier
    return @(
        Get-GerberAdoResponseValueList -Response $response |
            Where-Object { $_.name -like 'Template_*' -and -not $_.isDisabled } |
            ForEach-Object { [pscustomobject]@{ Id = [string]$_.id; Name = [string]$_.name; DefaultBranch = [string]$_.defaultBranch } }
    )
}
