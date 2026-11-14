function Assert-GerberPluginNamespaceAliasName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Alias
    )

    if ($Alias -cnotmatch '^[a-z][a-z0-9-]{0,63}$') {
        throw [System.ArgumentException]::new('Enter a lowercase namespace alias using letters, numbers or hyphens, starting with a letter.')
    }
    if (@('exit', 'help', 'plugins', 'update', 'tools', 'secrets') -contains $Alias) {
        throw [System.ArgumentException]::new("Namespace alias '$Alias' is a root reserved for Gerber Core. Choose another alias.")
    }
}
