function Get-GerberLocalNamespaceHolder {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Namespace,

        [Parameter(Mandatory)]
        [string]$Name
    )

    return @(Get-GerberPluginInventory) |
        Where-Object { $_.Name -ine $Name -and @($_.RegisteredNamespaceList) -contains $Namespace } |
        Select-Object -First 1
}
