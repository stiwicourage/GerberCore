function Get-GerberAdoRequestFailureMessage {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$Uri,

        [Parameter(Mandatory)]
        [string]$RequestLabel,

        [Parameter(Mandatory)]
        [Alias('CredentialIdentifier')]
        [string]$PatAccountIdentifier,

        [AllowNull()]
        [System.Exception]$Exception
    )

    $statusCode = Get-GerberAdoHttpStatusCode -Exception $Exception
    if ($statusCode -eq 401) {
        return "Gerber could not read Azure DevOps $RequestLabel because PAT credential '$PatAccountIdentifier' was rejected. Confirm the token is still valid, then update it with /secrets set."
    }

    if ($statusCode -eq 403) {
        return "Gerber could not read Azure DevOps $RequestLabel because PAT credential '$PatAccountIdentifier' does not have the required permissions. Update it with /secrets set after granting the required Azure DevOps access."
    }

    $transportHint = Get-GerberHttpTransportFailureHint -Exception $Exception
    if (-not [string]::IsNullOrWhiteSpace($transportHint)) {
        return "Gerber could not reach Azure DevOps at '$Uri'. $transportHint"
    }

    $reason = if ($null -eq $Exception -or [string]::IsNullOrWhiteSpace($Exception.Message)) {
        'Try again in a moment.'
    } else {
        $Exception.Message
    }

    return "Gerber could not read Azure DevOps $RequestLabel from '$Uri'. $reason"
}
