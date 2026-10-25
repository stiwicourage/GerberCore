<#
.SYNOPSIS
Returns the non-Gerber module fixture data.
#>
function Get-NonGerberModuleData {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    return 'plain-module'
}

Export-ModuleMember -Function 'Get-NonGerberModuleData'
