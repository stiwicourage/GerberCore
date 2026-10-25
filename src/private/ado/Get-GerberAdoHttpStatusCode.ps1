function Get-GerberAdoHttpStatusCode {
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
