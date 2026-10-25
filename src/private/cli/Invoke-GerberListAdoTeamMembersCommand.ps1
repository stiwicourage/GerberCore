function Invoke-GerberListAdoTeamMembersCommand {
    [CmdletBinding()]
    param()

    try {
        Show-GerberAdoTeamMemberReport
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
