function Test-GerberPluginBoundary {
    <#
    .SYNOPSIS
    Checks authored plugin source for identifiable private Gerber Core dependencies.
    .DESCRIPTION
    Parses source without executing it. Returns IsValid, FileCount, PublicApi and
    deterministic Diagnostics. This development check is not a PowerShell sandbox.
    .PARAMETER Path
    Plugin project directory containing authored PowerShell under src.
    .EXAMPLE
    $result = Test-GerberPluginBoundary -Path ./Gerber.Example
    $result.Diagnostics
    .EXAMPLE
    (Test-GerberPluginBoundary -Path .).PublicApi
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Position = 0)][string]$Path = '.')

    $contract = Get-GerberPluginBoundaryContract
    return Get-GerberPluginBoundaryResult -Path $Path -Contract $contract
}
