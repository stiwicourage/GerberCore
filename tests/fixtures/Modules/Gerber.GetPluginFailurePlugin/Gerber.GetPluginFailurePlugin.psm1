<#
.SYNOPSIS
Throws for the get-plugin-failure fixture.
#>
function Get-GerberPlugin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Gerber
    )

    throw [System.InvalidOperationException]::new(
        "Get-GerberPlugin failed for API version '$([string]$Gerber.ApiVersion)'."
    )
}

Export-ModuleMember -Function 'Get-GerberPlugin'
