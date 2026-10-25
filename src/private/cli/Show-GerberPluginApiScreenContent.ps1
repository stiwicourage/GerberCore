function Show-GerberPluginApiScreenContent {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Title,
        [string[]]$LineList = @()
    )
    $null = $PSCmdlet.ShouldProcess('Show-GerberPluginApiScreenContent', 'Invoke')

    Start-GerberScreen -Name $Title
    foreach ($line in @($LineList)) {
        Write-GerberScreenLine -Text $line
    }
}
