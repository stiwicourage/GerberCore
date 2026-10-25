function Get-GerberPropertiesData {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param()

    $propertiesPath = Get-GerberPropertiesPath
    try {
        return (Get-Content -LiteralPath $propertiesPath -Raw) | ConvertFrom-Json -AsHashtable
    } catch [System.ArgumentException] {
        throw [System.IO.InvalidDataException]::new("Gerber could not parse '$propertiesPath' as JSON.", $_.Exception)
    } catch [System.InvalidOperationException] {
        throw [System.IO.InvalidDataException]::new("Gerber could not parse '$propertiesPath' as JSON.", $_.Exception)
    }
}

function Get-GerberPropertiesPath {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    $candidatePathList = @(
        (Join-Path $PSScriptRoot 'resources/Properties.json')
        (Join-Path $PSScriptRoot '../../resources/Properties.json')
    )
    foreach ($candidatePath in $candidatePathList) {
        if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
            return [System.IO.Path]::GetFullPath($candidatePath)
        }
    }

    throw [System.IO.FileNotFoundException]::new("Gerber could not locate the settings file 'Properties.json'.")
}
