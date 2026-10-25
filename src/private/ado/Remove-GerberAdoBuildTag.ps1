function Remove-GerberAdoBuildTag {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [int]$BuildId,

        [Parameter(Mandatory)]
        [string]$Tag
    )

    $tagUri = Get-GerberAdoBuildTagDeleteUri -Configuration $Configuration -BuildId $BuildId -Tag $Tag
    $httpConfig = Get-GerberHttpConfiguration
    $null = $PSCmdlet.ShouldProcess("build $BuildId", "remove Azure DevOps tag '$Tag'")
    try {
        Invoke-RestMethod `
            -Method Delete `
            -Uri $tagUri `
            -ConnectionTimeoutSeconds $httpConfig.ConnectionTimeoutSeconds `
            -OperationTimeoutSeconds $httpConfig.OperationTimeoutSeconds `
            -Headers (Get-GerberAdoJsonRequestHeader -Pat $Pat) `
            -ErrorAction Stop | Out-Null
    } catch {
        if (Test-GerberAdoBuildTagMissingFailure -Exception $_.Exception) {
            return
        }

        throw [System.ArgumentException]::new(
            (Get-GerberAdoMutationFailureMessage `
                -Uri $tagUri `
                -RequestLabel "remove tag '$Tag' from build $BuildId" `
                -CredentialIdentifier $Configuration.CredentialIdentifier `
                -Exception $_.Exception),
            $_.Exception
        )
    }
}

function Get-GerberAdoBuildTagDeleteUri {
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

function Test-GerberAdoBuildTagMissingFailure {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [System.Exception]$Exception
    )

    if ($null -eq $Exception) {
        return $false
    }

    if ((Get-GerberAdoBuildTagFailureStatusCode -Exception $Exception) -eq 404) {
        return $true
    }

    return Test-GerberAdoBuildTagMissingFailure -Exception $Exception.InnerException
}

function Get-GerberAdoBuildTagFailureStatusCode {
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [System.Exception]$Exception
    )

    if ($null -eq $Exception) {
        return 0
    }

    if ($Exception.PSObject.Properties.Match('Response').Count -eq 0) {
        return 0
    }

    $response = $Exception.Response
    if ($null -eq $response) {
        return 0
    }

    if ($response.PSObject.Properties.Match('StatusCode').Count -eq 0) {
        return 0
    }

    return [int]$response.StatusCode
}
