function Disable-GerberPlugin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Guid
    )

    $snapshot = Get-GerberPluginDisableSnapshot
    try {
        $null = Set-GerberPluginAssociationState -Guid $Guid -Enabled $false
        Unregister-GerberPlugin -Guid $Guid
    } catch {
        Complete-GerberPluginDisableFailure -Guid $Guid -Snapshot $snapshot -Failure $_.Exception
    }
}

function Complete-GerberPluginDisableFailure {
    param(
        [string]$Guid,
        [pscustomobject]$Snapshot,
        [System.Exception]$Failure
    )

    Restore-GerberPluginDisableSnapshot -Snapshot $Snapshot -Failure $Failure
    throw [System.InvalidOperationException]::new(
        "Gerber could not disable plugin '$Guid': $($Failure.Message)", $Failure
    )
}

function Get-GerberPluginDisableSnapshot {
    [CmdletBinding()]
    param()

    $state = Get-Variable -Name GerberCommandRegistryState -Scope Script -ErrorAction SilentlyContinue
    $runtime = if ($null -ne $state -and $null -ne $state.Value) {
        Copy-GerberCommandRegistryState -State $state.Value
    }
    return [pscustomobject]@{
        Runtime = $runtime
        Configuration = Get-GerberUserConfiguration
    }
}

function Restore-GerberPluginDisableSnapshot {
    [CmdletBinding()]
    param(
        [pscustomobject]$Snapshot,
        [System.Exception]$Failure
    )

    $script:GerberCommandRegistryState = $Snapshot.Runtime
    try {
        Restore-GerberPluginDisableConfiguration -Configuration $Snapshot.Configuration
    } catch {
        throw (ConvertTo-GerberPluginDisableRollbackException -Failure $Failure -RollbackFailure $_.Exception)
    }
}

function Restore-GerberPluginDisableConfiguration {
    param(
        [hashtable]$Configuration
    )

    $current = ConvertTo-GerberUserConfigurationJson -Configuration (Get-GerberUserConfiguration)
    $previous = ConvertTo-GerberUserConfigurationJson -Configuration $Configuration
    if ($current -ne $previous) {
        Save-GerberUserConfiguration -Configuration $Configuration
    }
}

function ConvertTo-GerberPluginDisableRollbackException {
    param(
        [System.Exception]$Failure,
        [System.Exception]$RollbackFailure
    )

    $context = [System.AggregateException]::new([System.Exception[]]@($Failure, $RollbackFailure))
    return [System.InvalidOperationException]::new(
        "Gerber disable failed: $($Failure.Message). Rollback failed: $($RollbackFailure.Message)", $context
    )
}
