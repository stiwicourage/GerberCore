function Read-GerberPluginApiSecretText {
    [OutputType([string])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Prompt
    )
    $null = $PSCmdlet.ShouldProcess('Read-GerberPluginApiSecretText', 'Invoke')

    try {
        return ConvertTo-GerberSecretText -Value (Read-GerberSecureValue -Prompt $Prompt)
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) {
            return $null
        }

        throw
    }
}
