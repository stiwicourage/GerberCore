function Test-GerberAdoUnauthorizedFailure {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [System.Exception]$Exception
    )

    if ($null -eq $Exception) {
        return $false
    }

    $statusCode = Get-GerberAdoHttpStatusCode -Exception $Exception
    if (($statusCode -eq 401) -or ($statusCode -eq 403)) {
        return $true
    }

    return Test-GerberAdoUnauthorizedFailure -Exception $Exception.InnerException
}
