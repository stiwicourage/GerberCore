function Show-GerberPipelineReleaseRecoverableError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Show-GerberTextBlock -Title 'Error' -Text $Message
    try {
        Wait-GerberContinue
    } catch {
        if (-not (Test-GerberMenuEscapeException -Exception $_.Exception)) {
            throw
        }
    }
}
