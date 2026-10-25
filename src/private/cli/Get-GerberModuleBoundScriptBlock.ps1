function Get-GerberModuleBoundScriptBlock {
    [OutputType([scriptblock])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $module = $MyInvocation.MyCommand.Module
    if (($null -eq $module) -or ($module.Name -ne 'Gerber')) {
        return $ScriptBlock
    }

    return $module.NewBoundScriptBlock($ScriptBlock)
}
