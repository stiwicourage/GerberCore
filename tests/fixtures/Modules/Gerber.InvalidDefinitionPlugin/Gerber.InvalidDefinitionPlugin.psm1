<#
.SYNOPSIS
Returns the invalid-definition plugin fixture metadata.
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
                Name        = 'broken'
                Description = 'Broken command'
                Handler     = 'Invoke-Broken'
                Subcommands = [ordered]@{}
            }
        )
    }
}

Export-ModuleMember -Function 'Get-GerberPlugin'
