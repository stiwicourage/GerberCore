<#
.SYNOPSIS
Returns the first shared-conflict plugin fixture metadata.
#>
function Get-GerberPlugin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Gerber
    )

    $null = $Gerber

    return [pscustomobject]@{
        Commands = @(
            [pscustomobject][ordered]@{
                Name        = 'shared'
                Description = 'First shared command'
                Handler     = { param() $false }
                Subcommands = [ordered]@{}
            }
        )
    }
}

Export-ModuleMember -Function 'Get-GerberPlugin'
