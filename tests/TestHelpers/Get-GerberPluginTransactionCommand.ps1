function Get-GerberPluginTransactionCommand {
    param(
        [string]$Name,
        [System.Collections.IDictionary]$Subcommands = [ordered]@{}
    )

    return [pscustomobject]@{
        Name = $Name
        Description = "Run $Name"
        Handler = { return $true }
        Subcommands = $Subcommands
    }
}
