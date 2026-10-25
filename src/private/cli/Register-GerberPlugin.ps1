function Register-GerberPlugin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PluginModule
    )

    $previousState = Resolve-GerberPluginRegistrationState
    $registryBuilder = Copy-GerberPluginRegistrationBuilder -State $previousState
    try {
        Complete-GerberPluginRuntimeRegistration -RegistryBuilder $registryBuilder -PluginModule $PluginModule
    } catch {
        $script:GerberCommandRegistryState = $previousState
        throw
    }
}

function Resolve-GerberPluginRegistrationState {
    param()

    $state = Get-GerberRegisteredCommandRegistryState
    if ($null -eq $state) {
        throw [System.InvalidOperationException]::new('Gerber command registry has not been initialized for this session.')
    }
    return $state
}

function Copy-GerberPluginRegistrationBuilder {
    param(
        [pscustomobject]$State
    )

    $stagedState = Copy-GerberCommandRegistryState -State $State
    return [pscustomobject][ordered]@{
        CommandList   = [System.Collections.Generic.List[object]]::new([object[]]@($stagedState.CommandList))
        PluginList    = [System.Collections.Generic.List[object]]::new([object[]]@($State.PluginList))
        GerberVersion = [System.Management.Automation.SemanticVersion]::Parse([string]$State.GerberVersion)
    }
}

function Complete-GerberPluginRuntimeRegistration {
    param(
        [pscustomobject]$RegistryBuilder,
        [pscustomobject]$PluginModule
    )

    Add-GerberPluginToRegistryBuilder `
        -RegistryBuilder $RegistryBuilder `
        -PluginModule $PluginModule `
        -LifecycleState ([pscustomobject]@{ IsAssociated = $true; IsEnabled = $true })
    Publish-GerberCommandRegistryState -RegistryBuilder $RegistryBuilder
}
