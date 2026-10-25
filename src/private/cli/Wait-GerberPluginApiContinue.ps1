function Wait-GerberPluginApiContinue {
    [OutputType([bool])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('Wait-GerberPluginApiContinue', 'Invoke')

    try {
        Wait-GerberContinue
        return $true
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) {
            return $false
        }

        throw
    }
}
