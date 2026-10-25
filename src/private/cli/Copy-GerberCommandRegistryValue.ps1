function Copy-GerberCommandRegistryValue {
    [OutputType([object], [object[]])]
    [CmdletBinding()]
    param(
        [AllowNull()][object]$Value,
        [System.Collections.Generic.Dictionary[object, object]]$Memo
    )

    if ($null -eq $Value) {
        return $null
    }
    return Resolve-GerberCommandRegistryCopy -Value $Value -Memo $Memo
}

function Resolve-GerberCommandRegistryCopy {
    param(
        [object]$Value,
        [System.Collections.Generic.Dictionary[object, object]]$Memo
    )

    if ($Memo.ContainsKey($Value)) {
        return ,$Memo[$Value]
    }
    if ($Value -is [System.Collections.IDictionary]) {
        return Copy-GerberCommandRegistryDictionary -Value $Value -Memo $Memo
    }
    return Copy-GerberCommandRegistryEntry -Value $Value -Memo $Memo
}

function Copy-GerberCommandRegistryDictionary {
    param(
        [System.Collections.IDictionary]$Value,
        [System.Collections.Generic.Dictionary[object, object]]$Memo
    )

    $copy = [ordered]@{}
    $Memo.Add($Value, $copy)
    foreach ($key in $Value.Keys) {
        $copy[$key] = Copy-GerberCommandRegistryValue -Value $Value[$key] -Memo $Memo
    }
    return ,$copy
}

function Copy-GerberCommandRegistryEntry {
    param(
        [object]$Value,
        [System.Collections.Generic.Dictionary[object, object]]$Memo
    )

    if (($Value -isnot [pscustomobject]) -or ($null -eq $Value.PSObject.Properties['Subcommands'])) {
        return ,$Value
    }
    $copy = $Value.PSObject.Copy()
    $Memo.Add($Value, $copy)
    $copy.Subcommands = Copy-GerberCommandRegistryValue -Value $Value.Subcommands -Memo $Memo
    return $copy
}
