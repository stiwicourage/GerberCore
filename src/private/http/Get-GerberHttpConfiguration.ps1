function Get-GerberHttpConfiguration {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param()

    $properties = Get-GerberPropertiesData

    return [pscustomobject]@{
        ConnectionTimeoutSeconds = [int]$properties.HttpConnectionTimeoutSeconds
        OperationTimeoutSeconds = [int]$properties.HttpOperationTimeoutSeconds
    }
}
