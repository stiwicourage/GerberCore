function Invoke-GerberListAdoAgentsCommand {
    [CmdletBinding()]
    param()

    try {
        Show-GerberAdoAgentReport
        Wait-GerberContinue
    } catch [System.ArgumentException] {
        Show-GerberTextBlock -Title 'Error' -Text $_.Exception.Message
        try {
            $null = Wait-GerberContinue
        } catch {
            if (-not (Test-GerberMenuEscapeException -Exception $_.Exception)) {
                throw
            }
        }
    } catch {
        if (-not (Test-GerberMenuEscapeException -Exception $_.Exception)) {
            throw
        }
    }
}
