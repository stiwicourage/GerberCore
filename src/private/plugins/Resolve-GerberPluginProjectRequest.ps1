function Resolve-GerberPluginProjectRequest {
    param([hashtable]$InputMap)

    $inputMap = Initialize-GerberPluginProjectInputMap -InputMap $InputMap
    foreach ($field in @('Suffix', 'Description', 'Namespace', 'ParentPath')) {
        Assert-GerberPluginProjectInput -Field $field -Value $inputMap[$field]
    }
    if ($inputMap.ContainsKey('RepositoryUri')) {
        Assert-GerberPluginProjectInput -Field RepositoryUri -Value $inputMap.RepositoryUri
    }
    $request = ConvertTo-GerberPluginProjectRequest -InputMap $inputMap
    if ($inputMap.ContainsKey('RepositoryUri')) {
        $request | Add-Member -NotePropertyName RepositoryUri -NotePropertyValue $inputMap.RepositoryUri
    }
    return $request
}

function Initialize-GerberPluginProjectInputMap {
    param([hashtable]$InputMap)

    # Required fields: Suffix, Description, Namespace; optional ParentPath and RepositoryUri.
    $values = $InputMap.Clone()
    if (-not $values.ContainsKey('ParentPath')) {
        $values.ParentPath = (Get-Location).ProviderPath
    }
    return $values
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
