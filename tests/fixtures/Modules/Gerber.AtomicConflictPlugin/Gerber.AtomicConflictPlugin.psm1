<#
.SYNOPSIS
Returns the atomic-conflict plugin fixture metadata.
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
                Name        = 'alpha-plugin'
                Description = 'Would have been registered first'
                Handler     = { param() $false }
                Subcommands = [ordered]@{}
            }
            [pscustomobject][ordered]@{
                Name        = 'tools'
                Description = 'Conflicts with core'
                Handler     = { param() $false }
                Subcommands = [ordered]@{}
            }
        )
    }
}

Export-ModuleMember -Function 'Get-GerberPlugin'
