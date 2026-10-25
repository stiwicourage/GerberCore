function Set-GerberCoreUpdateChannel {
    [OutputType([bool])]
    [CmdletBinding(SupportsShouldProcess)]
    param([ValidateSet('Stable', 'IncludePrerelease')][string]$Channel)
    $configuration = Get-GerberUserConfiguration
    $policy = Resolve-GerberCoreUpdatePolicy -Configuration $configuration
    if ($policy.Channel -ceq $Channel) { return $false }
    if (-not $PSCmdlet.ShouldProcess('Core update policy', "Select $Channel")) { return $false }
    if (-not $configuration.Contains('coreUpdates')) { $configuration.coreUpdates = @{} }
    $configuration.coreUpdates.channel = $Channel
    Save-GerberUserConfiguration -Configuration $configuration -Confirm:$false
    Remove-Variable -Name GerberStartupUpdateState -Scope Script -ErrorAction SilentlyContinue
    $true
}
