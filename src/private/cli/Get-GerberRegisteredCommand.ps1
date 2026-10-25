function Get-GerberRegisteredCommand {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    foreach ($commandDefinition in (Get-GerberCommandRegistry)) {
        if ($commandDefinition.Name -ieq $Name) {
            return $commandDefinition
        }
    }

    return $null
}
