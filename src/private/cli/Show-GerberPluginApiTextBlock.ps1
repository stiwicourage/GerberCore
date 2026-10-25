function Show-GerberPluginApiTextBlock {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Title,
        [AllowEmptyString()]
        [string]$Text
    )
    $null = $PSCmdlet.ShouldProcess('Show-GerberPluginApiTextBlock', 'Invoke')

    Show-GerberTextBlock -Title $Title -Text $Text
}
