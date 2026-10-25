<#
.SYNOPSIS
Returns the named-parameter plugin fixture metadata.
#>
function Get-GerberPlugin {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Gerber
    )

    if ([string]$Gerber.ApiVersion -ne '1') {
        throw "Expected plugin API version '1' but received '$([string]$Gerber.ApiVersion)'."
    }

    return [pscustomobject][ordered]@{
        Commands = @()
    }
}

Export-ModuleMember -Function 'Get-GerberPlugin'
