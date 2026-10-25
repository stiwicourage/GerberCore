function Get-GerberAdoPipelineList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat
    )

    $relPath = "$($Configuration.ProjectName)/_apis/pipelines"
    $uri = Get-GerberAdoBranchRequestUri -Configuration $Configuration -RelativePath $relPath
    $response = Invoke-GerberAdoRestRequest `
        -Uri $uri `
        -Pat $Pat `
        -RequestLabel 'pipelines' `
        -CredentialIdentifier $Configuration.CredentialIdentifier
    return @(
        Get-GerberAdoResponseValueList -Response $response |
            ForEach-Object { [pscustomobject]@{ Id = [int]$_.id; Name = [string]$_.name } }
    )
}
