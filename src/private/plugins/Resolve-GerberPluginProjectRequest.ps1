function Resolve-GerberPluginProjectRequest {
    param(
        [AllowEmptyString()][string]$Suffix,
        [AllowEmptyString()][string]$Description,
        [AllowEmptyString()][string]$Namespace,
        [string]$ParentPath = (Get-Location).ProviderPath
    )

    $inputMap = @{ Suffix = $Suffix; Description = $Description; Namespace = $Namespace; ParentPath = $ParentPath }
    foreach ($field in $inputMap.Keys) {
        Assert-GerberPluginProjectInput -Field $field -Value $inputMap[$field]
    }
    return ConvertTo-GerberPluginProjectRequest -InputMap $inputMap
}

function ConvertTo-GerberPluginProjectRequest {
    param([hashtable]$InputMap)

    $parent = (Get-Item -LiteralPath $InputMap.ParentPath -ErrorAction Stop).FullName
    $destination = Join-Path $parent "Gerber.$($InputMap.Suffix)"
    Assert-GerberPluginProjectDestination -Destination $destination
    return [pscustomobject]@{
        Name = "Gerber.$($InputMap.Suffix)"
        Suffix = $InputMap.Suffix
        Description = $InputMap.Description
        Namespace = $InputMap.Namespace
        ParentPath = $parent
        Destination = $destination
    }
}

function Assert-GerberPluginProjectDestination {
    param([string]$Destination)

    if (Test-Path -LiteralPath $Destination) {
        throw [System.ArgumentException]::new("Destination '$Destination' already exists. Choose another module suffix or destination parent; Gerber never overwrites it.")
    }
}
