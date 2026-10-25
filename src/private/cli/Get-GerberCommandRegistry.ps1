function Get-GerberCommandRegistry {
    [OutputType([object[]])]
    [CmdletBinding()]
    param()

    $registryState = Get-Variable `
        -Name 'GerberCommandRegistryState' `
        -Scope Script `
        -ErrorAction SilentlyContinue
    if ($null -eq $registryState -or $null -eq $registryState.Value) {
        throw [System.InvalidOperationException]::new(
            'Gerber command registry has not been initialized for this session.'
        )
    }

    return @($registryState.Value.CommandList)
}
