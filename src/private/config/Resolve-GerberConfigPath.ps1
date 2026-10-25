function Resolve-GerberConfigPath {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).ProviderPath '.gerber/config.json'))
    }

    return [System.IO.Path]::GetFullPath($Path)
}
