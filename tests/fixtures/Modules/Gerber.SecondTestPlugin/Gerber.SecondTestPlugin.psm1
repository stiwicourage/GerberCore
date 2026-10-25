$script:GerberSecondTestPluginRegistrationContext = $null

<#
.SYNOPSIS
Returns the second test-plugin fixture metadata.
#>
function Get-GerberPlugin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Gerber
    )

    $script:GerberSecondTestPluginRegistrationContext = $Gerber

    return [pscustomobject]@{
        Commands = @(
            [pscustomobject][ordered]@{
                Name        = 'example-two'
                Description = 'Run the second Gerber test plugin command'
                Handler     = {
                    param([pscustomobject]$Command, [pscustomobject]$PluginApi)

                    $null = $Command, $PluginApi
                    $false
                }
                Subcommands = [ordered]@{}
            }
        )
    }
}

<#
.SYNOPSIS
Returns the captured registration context for the second test plugin.
#>
function Get-GerberSecondTestPluginRegistrationContext {
    [CmdletBinding()]
    param()

    return $script:GerberSecondTestPluginRegistrationContext
}

Export-ModuleMember -Function `
    'Get-GerberPlugin', `
    'Get-GerberSecondTestPluginRegistrationContext'
