function Assert-GerberPluginsActivationCommandInput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Command,

        [Parameter(Mandatory)]
        [string]$CommandName
    )

    $argumentProperty = $Command.PSObject.Properties['Arguments']
    if ($null -eq $argumentProperty -or @($argumentProperty.Value).Count -eq 0) {
        return
    }

    throw [System.ArgumentException]::new(
        "The '/plugins $CommandName' command does not accept extra arguments."
    )
}
