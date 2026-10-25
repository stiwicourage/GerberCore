function Get-GerberPluginTemplatePath {
    foreach ($relativePath in @('resources/plugin-template', '../../resources/plugin-template')) {
        $path = Join-Path $PSScriptRoot $relativePath
        if (Test-Path -LiteralPath $path -PathType Container) {
            return [System.IO.Path]::GetFullPath($path)
        }
    }
    throw [System.IO.DirectoryNotFoundException]::new('Gerber plugin templates are missing. Rebuild or reinstall Gerber.')
}
