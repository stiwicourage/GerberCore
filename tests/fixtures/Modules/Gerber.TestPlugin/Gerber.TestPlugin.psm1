$script:GerberTestPluginInvocationCount = 0
$script:GerberTestPluginHandlerContext = $null
$script:GerberTestPluginRegistrationContext = $null
$script:GerberTestPluginHandler = {
    param(
        [pscustomobject]$Command,
        [pscustomobject]$Gerber
    )

    Invoke-GerberTestPluginCommand -Command $Command -Gerber $Gerber
}

function Invoke-GerberTestPluginCommand {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Command,

        [Parameter(Mandatory)]
        [pscustomobject]$Gerber
    )

    $script:GerberTestPluginInvocationCount++
    $script:GerberTestPluginHandlerContext = $Gerber
    $script:GerberTestPluginLastCommandName = [string]$Command.Name
    return $false
}

<#
.SYNOPSIS
Returns the test-plugin fixture metadata.
#>
function Get-GerberPlugin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Gerber
    )

    $script:GerberTestPluginRegistrationContext = $Gerber

    return [pscustomobject]@{
        Commands = @(
            [pscustomobject][ordered]@{
                Name        = 'example'
                Description = 'Run the Gerber test plugin command'
                Handler     = $script:GerberTestPluginHandler
                Subcommands = [ordered]@{}
            }
        )
    }
}

<#
.SYNOPSIS
Returns the number of test-plugin command invocations.
#>
function Get-GerberTestPluginInvocationCount {
    [OutputType([int])]
    [CmdletBinding()]
    param()

    return $script:GerberTestPluginInvocationCount
}

<#
.SYNOPSIS
Returns the captured registration context for the test plugin.
#>
function Get-GerberTestPluginRegistrationContext {
    [CmdletBinding()]
    param()

    return $script:GerberTestPluginRegistrationContext
}

<#
.SYNOPSIS
Returns the captured handler context for the test plugin.
#>
function Get-GerberTestPluginHandlerContext {
    [CmdletBinding()]
    param()

    return $script:GerberTestPluginHandlerContext
}

<#
.SYNOPSIS
Resets the tracked test-plugin invocation state.
#>
function Reset-GerberTestPluginInvocationCount {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess('Gerber.TestPlugin invocation state', 'Reset')) {
        $script:GerberTestPluginInvocationCount = 0
        $script:GerberTestPluginHandlerContext = $null
        $script:GerberTestPluginLastCommandName = $null
    }
}

Export-ModuleMember -Function `
    'Get-GerberPlugin', `
    'Get-GerberTestPluginHandlerContext', `
    'Get-GerberTestPluginInvocationCount', `
    'Get-GerberTestPluginRegistrationContext', `
    'Reset-GerberTestPluginInvocationCount'
