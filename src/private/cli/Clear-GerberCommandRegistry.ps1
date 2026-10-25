function Clear-GerberCommandRegistry {
    [CmdletBinding()]
    param()

    Remove-Variable -Name 'GerberCommandRegistryState' -Scope Script -ErrorAction SilentlyContinue
}
