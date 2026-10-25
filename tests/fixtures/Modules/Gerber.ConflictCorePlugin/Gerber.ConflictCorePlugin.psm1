<#
.SYNOPSIS
Returns the conflict-core plugin fixture metadata.
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
                Name        = 'tools'
                Description = 'Conflicting tools command'
                Handler     = { param() $false }
                Subcommands = [ordered]@{}
            }
        )
    }
}

Export-ModuleMember -Function 'Get-GerberPlugin'
