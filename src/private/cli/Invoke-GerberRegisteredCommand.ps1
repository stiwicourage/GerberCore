function Invoke-GerberRegisteredCommand {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$CommandDefinition,

        [Parameter(Mandatory)]
        [pscustomobject]$Command
    )

    if ($CommandDefinition.Handler -isnot [scriptblock]) {
        throw [System.ArgumentException]::new(
            "Gerber command '$($CommandDefinition.Name)' does not define a valid handler scriptblock."
        )
    }

    $result = Invoke-GerberRegisteredCommandHandler -CommandDefinition $CommandDefinition -Command $Command
    if ($result -is [bool]) {
        return $result
    }

    if ($null -eq $result) {
        return $false
    }

    throw [System.InvalidOperationException]::new(
        "Gerber command '$($CommandDefinition.Name)' returned an invalid handler result type '$($result.GetType().FullName)'."
    )
}

function Invoke-GerberRegisteredCommandHandler {
    [OutputType([object])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$CommandDefinition,

        [Parameter(Mandatory)]
        [pscustomobject]$Command
    )

    if ([string]$CommandDefinition.OwnerType -eq 'Plugin') {
        $pluginContext = Get-GerberRegisteredPluginApiContext -OwnerName $CommandDefinition.OwnerName
        return (& $CommandDefinition.Handler $Command $pluginContext)
    }

    return (& $CommandDefinition.Handler $Command)
}

function Get-GerberRegisteredPluginApiContext {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OwnerName
    )

    $registryState = Get-Variable `
        -Name 'GerberCommandRegistryState' `
        -Scope Script `
        -ErrorAction SilentlyContinue
    if ($null -eq $registryState -or $null -eq $registryState.Value) {
        throw [System.InvalidOperationException]::new(
            'Gerber command registry has not been initialized for this session.'
        )
    }

    foreach ($pluginState in @($registryState.Value.PluginList)) {
        if ([string]$pluginState.Name -ieq $OwnerName) {
            return $pluginState.PluginApiContext
        }
    }

    throw [System.InvalidOperationException]::new(
        "Gerber command '$OwnerName' does not have an initialized plugin API context."
    )
}
