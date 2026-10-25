<#
.SYNOPSIS
Returns the missing-entry-point fixture metadata.
#>
function Get-GerberPluginInfo {
    [CmdletBinding()]
    param()

    return [pscustomobject]@{
        Name = 'Missing'
    }
}

Export-ModuleMember -Function 'Get-GerberPluginInfo'
