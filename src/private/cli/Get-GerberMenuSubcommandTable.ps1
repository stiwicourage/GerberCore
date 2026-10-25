function Get-GerberMenuSubcommandTable {
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName
    )

    $commandDefinition = Get-GerberRegisteredCommand -Name $CommandName
    if ($null -eq $commandDefinition) {
        return [ordered]@{}
    }

    return $commandDefinition.Subcommands
}
