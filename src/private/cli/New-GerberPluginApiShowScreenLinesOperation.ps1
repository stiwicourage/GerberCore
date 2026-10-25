function New-GerberPluginApiShowScreenLinesOperation {
    [OutputType([scriptblock])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiShowScreenLinesOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param(
            [string]$Title,
            [string[]]$LineList = @()
        )

        Show-GerberPluginApiScreenContent -Title $Title -LineList $LineList
    }
}
