function Set-GerberPluginNamespaceAlias {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [AllowNull()]
        [hashtable]$Configuration,

        [Parameter(Mandatory)]
        [string]$Guid,

        [AllowNull()]
        [string]$Alias
    )

    if ($null -eq $Configuration) {
        $Configuration = Get-GerberUserConfiguration
    }
    $normalizedGuid = ([guid]$Guid).ToString('D').ToLowerInvariant()
    if (-not [string]::IsNullOrEmpty($Alias)) {
        Assert-GerberPluginNamespaceAlias -Alias $Alias -AliasTable (Get-GerberPluginNamespaceAliasTable -Configuration $Configuration) -Guid $normalizedGuid
    }
    if (-not $PSCmdlet.ShouldProcess($normalizedGuid, 'Set Gerber plugin namespace alias')) {
        return
    }

    $aliasTable = Get-GerberPluginNamespaceAliasTable -Configuration $Configuration
    if ([string]::IsNullOrEmpty($Alias)) {
        $aliasTable.Remove($normalizedGuid)
    } else {
        $aliasTable[$normalizedGuid] = $Alias
    }
    Save-GerberUserConfiguration -Configuration $Configuration
}

function Get-GerberPluginNamespaceAliasTable {
    param([hashtable]$Configuration)

    if ($Configuration['plugins'] -isnot [System.Collections.IDictionary]) {
        $Configuration['plugins'] = @{}
    }
    if ($Configuration['plugins']['aliases'] -isnot [System.Collections.IDictionary]) {
        $Configuration['plugins']['aliases'] = @{}
    }

    return $Configuration['plugins']['aliases']
}

function Assert-GerberPluginNamespaceAlias {
    param([string]$Alias, [System.Collections.IDictionary]$AliasTable, [string]$Guid)

    Assert-GerberPluginNamespaceAliasName -Alias $Alias
    foreach ($key in @($AliasTable.Keys)) {
        if (($key -ne $Guid) -and ($AliasTable[$key] -ceq $Alias)) {
            throw [System.ArgumentException]::new("Namespace alias '$Alias' is already used by another plugin. Choose another alias.")
        }
    }
}
