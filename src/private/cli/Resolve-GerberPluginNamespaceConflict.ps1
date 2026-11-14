function Resolve-GerberPluginNamespaceConflict {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$RegistryBuilder,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$CommandDefinitionList,

        [Parameter(Mandatory)]
        [string]$OwnerName
    )

    $withheldList = Get-GerberBuilderWithheldRootList -RegistryBuilder $RegistryBuilder
    # Only a plugin that declares the root command itself claims the namespace; shared parent containers are not conflicts.
    $declaredRootList = @($CommandDefinitionList | Where-Object { $_.Name.Trim() -notmatch ' ' } | ForEach-Object { Get-GerberCommandRootName -Name $_.Name })
    $conflictRootList = @(
        $CommandDefinitionList | ForEach-Object { Get-GerberCommandRootName -Name $_.Name } | Select-Object -Unique |
            Where-Object { Test-GerberPluginRootConflict -RegistryBuilder $RegistryBuilder -Root $_ -OwnerName $OwnerName -DeclaredRootList $declaredRootList }
    )
    foreach ($root in $conflictRootList) {
        Add-GerberWithheldPluginRoot -RegistryBuilder $RegistryBuilder -WithheldList $withheldList -Root $root -OwnerName $OwnerName
    }

    return @($CommandDefinitionList | Where-Object { $conflictRootList -notcontains (Get-GerberCommandRootName -Name $_.Name) })
}

function Get-GerberCommandRootName {
    param([string]$Name)

    return $Name.Trim().Split(' ')[0].ToLowerInvariant()
}

function Get-GerberBuilderWithheldRootList {
    param([pscustomobject]$RegistryBuilder)

    if ($null -eq $RegistryBuilder.PSObject.Properties['WithheldRootList']) {
        $RegistryBuilder | Add-Member -NotePropertyName WithheldRootList -NotePropertyValue ([System.Collections.Generic.List[object]]::new())
    }
    return ,$RegistryBuilder.WithheldRootList
}

function Get-GerberPluginRootOwnerList {
    param([pscustomobject]$RegistryBuilder, [string]$Root)

    return @(
        $RegistryBuilder.CommandList |
            Where-Object { ($_.OwnerType -eq 'Plugin') -and ($_.Name.Trim() -ieq $Root) } |
            ForEach-Object { $_.OwnerName } | Select-Object -Unique
    )
}

function Test-GerberPluginRootConflict {
    param([pscustomobject]$RegistryBuilder, [string]$Root, [string]$OwnerName, [string[]]$DeclaredRootList)

    $withheld = $RegistryBuilder.WithheldRootList | Where-Object { $_.Root -eq $Root }
    $otherOwnerList = @(Get-GerberPluginRootOwnerList -RegistryBuilder $RegistryBuilder -Root $Root | Where-Object { $_ -ine $OwnerName })
    return ($null -ne $withheld) -or (($DeclaredRootList -contains $Root) -and ($otherOwnerList.Count -gt 0))
}

function Add-GerberWithheldPluginRoot {
    param([pscustomobject]$RegistryBuilder, [System.Collections.Generic.List[object]]$WithheldList, [string]$Root, [string]$OwnerName)

    $entry = $WithheldList | Where-Object { $_.Root -eq $Root } | Select-Object -First 1
    $existingOwnerList = @(Get-GerberPluginRootOwnerList -RegistryBuilder $RegistryBuilder -Root $Root)
    if ($null -eq $entry) {
        $entry = [pscustomobject]@{ Root = $Root; OwnerNameList = @() }
        $WithheldList.Add($entry)
    }
    $entry.OwnerNameList = @($entry.OwnerNameList + $existingOwnerList + $OwnerName | Select-Object -Unique)
    $null = $RegistryBuilder.CommandList.RemoveAll({ param($c) ($c.OwnerType -eq 'Plugin') -and ((Get-GerberCommandRootName -Name $c.Name) -eq $Root) })
    $ownerText = ($entry.OwnerNameList | ForEach-Object { "'$_'" }) -join ', '
    Write-Warning "Gerber withheld the commands under '/$Root' because more than one plugin registers that namespace: $ownerText. Give one plugin its own namespace to use them."
}
