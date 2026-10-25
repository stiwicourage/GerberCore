function Get-GerberPluginLoadedText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [bool]$Loaded
    )

    if ($Loaded) {
        return 'Yes'
    }

    return 'No'
}
