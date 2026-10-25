function New-GerberPluginApiWriteScreenLineOperation {
    [OutputType([scriptblock])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiWriteScreenLineOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param(
            [string]$Text = ''
        )

        Write-GerberScreenLine -Text $Text
    }
}
