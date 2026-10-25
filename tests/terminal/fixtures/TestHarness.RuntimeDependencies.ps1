function Import-GerberTerminalRuntimeDependency {
    param([string]$GerberRoot)
    $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $GerberRoot 'dist/Gerber/Gerber.psd1')
    foreach ($requirement in $manifest.RequiredModules) {
        Import-Module -FullyQualifiedName $requirement -ErrorAction Stop
    }
}
