<#
.SYNOPSIS
Returns the incompatible-version plugin fixture metadata.
#>
function Get-GerberPlugin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Gerber
    )

    $null = $Gerber

    return [pscustomobject]@{
        Commands = @()
    }
}

Export-ModuleMember -Function 'Get-GerberPlugin'
