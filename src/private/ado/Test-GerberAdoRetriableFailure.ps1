function Test-GerberAdoRetriableFailure {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [System.Exception]$Exception
    )

    if ($null -eq $Exception) {
        return $false
    }

    if (Test-GerberHttpTimeoutFailure -Exception $Exception) {
        return $true
    }

    $statusCode = Get-GerberAdoHttpStatusCode -Exception $Exception
    if ($statusCode -in @(408, 429, 502, 503, 504)) {
        return $true
    }

    return Test-GerberAdoRetriableFailure -Exception $Exception.InnerException
}
