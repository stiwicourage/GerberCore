function Initialize-GerberCommandRegistry {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [string[]]$PluginModulePathList = (Get-GerberDefaultPluginModulePathList)
    )

    $existingRegistryState = Get-Variable `
        -Name 'GerberCommandRegistryState' `
        -Scope Script `
        -ErrorAction SilentlyContinue
    if ($null -ne $existingRegistryState -and $null -ne $existingRegistryState.Value) {
        return @(Get-GerberRootCommandDefinitionList -CommandDefinitionList $existingRegistryState.Value.CommandList)
    }

    $registryBuilder = [pscustomobject][ordered]@{
        CommandList   = New-Object 'System.Collections.Generic.List[object]'
        PluginList    = New-Object 'System.Collections.Generic.List[object]'
        GerberVersion = Get-GerberCurrentVersion
    }

    Add-GerberOwnedCommandDefinitionList `
        -RegisteredCommandList $registryBuilder.CommandList `
        -CommandDefinitionList (Get-GerberCoreCommandDefinitionList) `
        -OwnerName 'Gerber.Core' `
        -OwnerType 'Core'

    foreach ($pluginModule in (Get-GerberDiscoveredPluginModuleList -PluginModulePathList $PluginModulePathList)) {
        if (-not (Resolve-GerberPluginApproval -PluginModule $pluginModule)) {
            continue
        }

        $lifecycleState = Get-GerberPluginLifecycleState -Guid $pluginModule.Guid
        if (-not $lifecycleState.ShouldLoad) {
            continue
        }

        Add-GerberPluginToRegistryBuilder `
            -RegistryBuilder $registryBuilder `
            -PluginModule $pluginModule `
            -LifecycleState $lifecycleState
    }

    Publish-GerberCommandRegistryState -RegistryBuilder $registryBuilder

    return @(Get-GerberRootCommandDefinitionList -CommandDefinitionList $script:GerberCommandRegistryState.CommandList)
}

function Get-GerberDefaultPluginModulePathList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param()

    if ([string]::IsNullOrWhiteSpace($env:PSModulePath)) {
        return [string[]]@()
    }

    return [string[]]@(
        foreach ($path in ($env:PSModulePath -split [System.IO.Path]::PathSeparator)) {
            if (-not [string]::IsNullOrWhiteSpace($path)) {
                $path
            }
        }
    )
}

function Get-GerberCurrentVersion {
    [OutputType([System.Management.Automation.SemanticVersion])]
    [CmdletBinding()]
    param()

    $loadedVersion = Get-GerberLoadedCommandVersion
    if ($null -ne $loadedVersion) {
        return $loadedVersion
    }

    $projectVersion = Get-GerberProjectVersionFromRepositoryRoot
    return [System.Management.Automation.SemanticVersion]::Parse($projectVersion)
}

function Get-GerberLoadedCommandVersion {
    [OutputType([System.Management.Automation.SemanticVersion])]
    [CmdletBinding()]
    param()

    $command = Get-Command -Name 'Invoke-Gerber' -CommandType Function -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        return $null
    }

    if ($null -eq $command.Module) {
        return $null
    }

    if ($null -eq $command.Module.Version) {
        return $null
    }

    return [System.Management.Automation.SemanticVersion]::Parse($command.Module.Version.ToString())
}

function Get-GerberProjectVersionFromRepositoryRoot {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    $projectPath = Join-Path (Get-Location) 'project.json'
    if (-not (Test-Path -LiteralPath $projectPath -PathType Leaf)) {
        throw [System.InvalidOperationException]::new(
            'Gerber could not resolve the current version because project.json was not available from the current working directory.'
        )
    }

    $projectData = (Get-Content -LiteralPath $projectPath -Raw) | ConvertFrom-Json -AsHashtable
    return [string]$projectData.Version
}

function Get-GerberDiscoveredPluginModuleList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [string[]]$PluginModulePathList
    )

    $pluginModuleList = @(
        foreach ($moduleInfo in (Get-GerberPluginManifestMetadataList -PluginModulePathList $PluginModulePathList)) {
            Assert-GerberPluginModuleManifest -ModuleInfo $moduleInfo
            $moduleInfo
        }
    )

    $selectedModuleList = @(
        foreach ($group in ($pluginModuleList | Group-Object Name)) {
            $group.Group |
                Sort-Object @{ Expression = { [version]$_.Version }; Descending = $true } |
                Select-Object -First 1
        }
    )

    return @(
        $selectedModuleList |
            Sort-Object @{ Expression = { $_.Name.ToLowerInvariant() } }, @{ Expression = { [version]$_.Version }; Descending = $true }
    )
}

function Assert-GerberPluginModuleManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$ModuleInfo
    )

    $gerberMetadata = Get-GerberModulePrivateDataValueOrNull -InputObject $ModuleInfo.PrivateData -Name 'Gerber'
    if ([string]::IsNullOrWhiteSpace([string]$gerberMetadata.ApiVersion)) {
        throw [System.InvalidOperationException]::new(
            "Gerber plugin '$($ModuleInfo.Name)' is missing required manifest metadata 'PrivateData.Gerber.ApiVersion'."
        )
    }

    if ([string]$gerberMetadata.ApiVersion -ne '1') {
        throw [System.InvalidOperationException]::new(
            "Gerber plugin '$($ModuleInfo.Name)' requires plugin API version '$([string]$gerberMetadata.ApiVersion)', but Gerber supports plugin API version '1'."
        )
    }

    if ([string]::IsNullOrWhiteSpace([string]$gerberMetadata.MinimumGerberVersion)) {
        throw [System.InvalidOperationException]::new(
            "Gerber plugin '$($ModuleInfo.Name)' is missing required manifest metadata 'PrivateData.Gerber.MinimumGerberVersion'."
        )
    }
}

function Get-GerberModulePrivateDataValueOrNull {
    [OutputType([object])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) {
            return $InputObject[$Name]
        }

        return $null
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Add-GerberOwnedCommandDefinitionList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$RegisteredCommandList,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$CommandDefinitionList,

        [Parameter(Mandatory)]
        [string]$OwnerName,

        [Parameter(Mandatory)]
        [ValidateSet('Core', 'Plugin')]
        [string]$OwnerType
    )

    $ownedCommandList = @()
    $registrationOrder = $RegisteredCommandList.Count
    foreach ($commandDefinition in $CommandDefinitionList) {
        $ownedCommand = ConvertTo-GerberOwnedCommandDefinition `
                -CommandDefinition $commandDefinition `
                -OwnerName $OwnerName `
                -OwnerType $OwnerType
        $ownedCommand | Add-Member -NotePropertyName RegistrationOrder -NotePropertyValue $registrationOrder
        $ownedCommandList += $ownedCommand
        $registrationOrder++
    }

    Assert-GerberOwnedCommandDefinitionList -OwnedCommandDefinitionList $ownedCommandList -RegisteredCommandList $RegisteredCommandList

    foreach ($ownedCommand in (Get-GerberOrderedOwnedCommandDefinitionList -OwnedCommandDefinitionList $ownedCommandList)) {
        if ($ownedCommand.ParentName) {
            Add-GerberOwnedSubcommandDefinition `
                -RegisteredCommandList $RegisteredCommandList `
                -OwnedCommandDefinition $ownedCommand
        }

        $null = $RegisteredCommandList.Add($ownedCommand)
    }
}

function ConvertTo-GerberOwnedCommandDefinition {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$CommandDefinition,

        [Parameter(Mandatory)]
        [string]$OwnerName,

        [Parameter(Mandatory)]
        [ValidateSet('Core', 'Plugin')]
        [string]$OwnerType
    )

    Assert-GerberCommandDefinition -CommandDefinition $CommandDefinition -OwnerName $OwnerName

    $commandName = Resolve-GerberCommandName -CommandName ([string]$CommandDefinition.Name)
    $ownedCommandDefinition = [pscustomobject][ordered]@{
        Name        = $commandName
        Description = [string]$CommandDefinition.Description
        Handler     = $CommandDefinition.Handler
        Subcommands = Get-GerberCommandDefinitionSubcommandTable -Subcommands $CommandDefinition.Subcommands
        OwnerName   = $OwnerName
        OwnerType   = $OwnerType
        ParentName  = Get-GerberParentCommandName -CommandName $commandName
        LeafName    = Get-GerberCommandLeafName -CommandName $commandName
    }

    return $ownedCommandDefinition
}

function Assert-GerberCommandDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$CommandDefinition,

        [Parameter(Mandatory)]
        [string]$OwnerName
    )

    if ([string]::IsNullOrWhiteSpace([string]$CommandDefinition.Name)) {
        throw [System.InvalidOperationException]::new(
            "Gerber plugin '$OwnerName' returned an invalid command definition because 'Name' was missing."
        )
    }

    if ([string]::IsNullOrWhiteSpace([string]$CommandDefinition.Description)) {
        throw [System.InvalidOperationException]::new(
            "Gerber plugin '$OwnerName' returned an invalid command definition for root command '$([string]$CommandDefinition.Name)' because 'Description' was missing."
        )
    }

    if ($CommandDefinition.Handler -isnot [scriptblock]) {
        throw [System.InvalidOperationException]::new(
            "Gerber plugin '$OwnerName' returned an invalid command definition for root command '$([string]$CommandDefinition.Name)' because 'Handler' was not a scriptblock."
        )
    }

    if (($null -ne $CommandDefinition.Subcommands) -and ($CommandDefinition.Subcommands -isnot [System.Collections.IDictionary])) {
        throw [System.InvalidOperationException]::new(
            "Gerber plugin '$OwnerName' returned an invalid command definition for root command '$([string]$CommandDefinition.Name)' because 'Subcommands' was not a dictionary."
        )
    }

}

function Assert-GerberOwnedCommandDefinitionList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$OwnedCommandDefinitionList,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$RegisteredCommandList
    )

    Assert-GerberOwnerCommandNamesAreUnique -OwnedCommandDefinitionList $OwnedCommandDefinitionList

    foreach ($ownedCommand in $OwnedCommandDefinitionList) {
        $existingCommand = Find-GerberRegisteredCommandConflict `
            -RegisteredCommandList $RegisteredCommandList `
            -CommandName $ownedCommand.Name
        if ($null -eq $existingCommand) {
            Assert-GerberOwnedCommandParentDefinition `
                -RegisteredCommandList $RegisteredCommandList `
                -OwnedCommandDefinitionList $OwnedCommandDefinitionList `
                -OwnedCommandDefinition $ownedCommand
            Assert-GerberOwnedSubcommandConflict `
                -RegisteredCommandList $RegisteredCommandList `
                -OwnedCommandDefinitionList $OwnedCommandDefinitionList `
                -OwnedCommandDefinition $ownedCommand
            continue
        }

        throw (Get-GerberRegisteredCommandConflictException -OwnedCommandDefinition $ownedCommand -ExistingCommandDefinition $existingCommand)
    }
}

function Assert-GerberOwnerCommandNamesAreUnique {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$OwnedCommandDefinitionList
    )

    foreach ($group in ($OwnedCommandDefinitionList | Group-Object Name)) {
        if ($group.Count -le 1) {
            continue
        }

        $ownedCommand = $group.Group[0]
        $commandKind = if ($ownedCommand.ParentName) { 'command' } else { 'root command' }
        throw [System.InvalidOperationException]::new(
            "Gerber cannot register duplicate $commandKind '$($group.Name)' from owner '$($ownedCommand.OwnerName)'."
        )
    }
}

function Find-GerberRegisteredCommandConflict {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$RegisteredCommandList,

        [Parameter(Mandatory)]
        [string]$CommandName
    )

    foreach ($registeredCommand in $RegisteredCommandList) {
        if ($registeredCommand.Name -ieq $CommandName) {
            return $registeredCommand
        }
    }

    return $null
}

function Get-GerberRootCommandDefinitionList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$CommandDefinitionList
    )

    return @(
        foreach ($commandDefinition in $CommandDefinitionList) {
            if (-not $commandDefinition.ParentName) {
                $commandDefinition
            }
        }
    )
}

function Resolve-GerberCommandName {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName
    )

    return (($CommandName -split '\s+') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ' '
}

function Get-GerberParentCommandName {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName
    )

    $tokenList = @(Get-GerberCommandNameTokenList -CommandName $CommandName)
    if ($tokenList.Count -le 1) {
        return $null
    }

    return (@($tokenList | Select-Object -SkipLast 1) -join ' ')
}

function Get-GerberCommandLeafName {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName
    )

    $tokenList = @(Get-GerberCommandNameTokenList -CommandName $CommandName)
    return $tokenList[-1]
}

function Get-GerberCommandNameTokenList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName
    )

    return [string[]]@((Resolve-GerberCommandName -CommandName $CommandName) -split '\s+')
}

function Get-GerberCommandDefinitionSubcommandTable {
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary]$Subcommands
    )

    if ($null -eq $Subcommands) {
        return [ordered]@{}
    }

    $orderedSubcommandTable = [ordered]@{}
    foreach ($subcommandName in $Subcommands.Keys) {
        $orderedSubcommandTable[$subcommandName] = $Subcommands[$subcommandName]
    }

    return $orderedSubcommandTable
}

function Get-GerberOrderedOwnedCommandDefinitionList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$OwnedCommandDefinitionList
    )

    return @(
        $OwnedCommandDefinitionList |
            Sort-Object `
                @{ Expression = { (@(Get-GerberCommandNameTokenList -CommandName $_.Name)).Count } }, `
                @{ Expression = { $_.RegistrationOrder } }
    )
}

function Assert-GerberOwnedCommandParentDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$RegisteredCommandList,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$OwnedCommandDefinitionList,

        [Parameter(Mandatory)]
        [pscustomobject]$OwnedCommandDefinition
    )

    # Preserve the existing collection/mandatory binding contract at this entry point.
    Assert-GerberCommandParentRegistration -Commands $RegisteredCommandList -Definitions $OwnedCommandDefinitionList -Command $OwnedCommandDefinition
}

function Assert-GerberCommandParentRegistration {
    param(
        [System.Collections.Generic.List[object]]$Commands,
        [object[]]$Definitions,
        [pscustomobject]$Command
    )

    if ($Command.ParentName) {
        $parent = Find-GerberRegisteredCommandConflict -RegisteredCommandList $Commands -CommandName $Command.ParentName
        Assert-GerberCommandParentOwnership -Parent $parent -Command $Command
        if ($null -eq $parent) {
            Assert-GerberDeclaredCommandParent -Definitions $Definitions -Command $Command
        }
    }
}

function Assert-GerberDeclaredCommandParent {
    param(
        [object[]]$Definitions,
        [pscustomobject]$Command
    )

    foreach ($candidate in $Definitions) {
        if ($candidate.Name -ieq $Command.ParentName) {
            return
        }
    }
    throw [System.InvalidOperationException]::new(
        "Gerber cannot register command '$($Command.Name)' from owner '$($Command.OwnerName)' because parent command '$($Command.ParentName)' is not registered."
    )
}

function Assert-GerberOwnedSubcommandConflict {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$RegisteredCommandList,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$OwnedCommandDefinitionList,

        [Parameter(Mandatory)]
        [pscustomobject]$OwnedCommandDefinition
    )

    if (-not $OwnedCommandDefinition.ParentName) {
        return
    }

    $parentCommand = Find-GerberRegisteredCommandConflict `
        -RegisteredCommandList $RegisteredCommandList `
        -CommandName $OwnedCommandDefinition.ParentName
    if ($null -eq $parentCommand) {
        foreach ($candidateCommand in $OwnedCommandDefinitionList) {
            if ($candidateCommand.Name -ieq $OwnedCommandDefinition.ParentName) {
                $parentCommand = $candidateCommand
                break
            }
        }
    }

    if (($null -eq $parentCommand) -or (-not $parentCommand.Subcommands.Contains($OwnedCommandDefinition.LeafName))) {
        return
    }

    $existingOwnedCommand = Find-GerberOwnedCommandDefinitionByParentAndLeafName `
        -OwnedCommandDefinitionList $OwnedCommandDefinitionList `
        -ParentName $OwnedCommandDefinition.ParentName `
        -LeafName $OwnedCommandDefinition.LeafName `
        -ExcludeName $OwnedCommandDefinition.Name
    if ($null -ne $existingOwnedCommand) {
        return
    }

    throw [System.InvalidOperationException]::new(
        "Gerber cannot register subcommand '$($OwnedCommandDefinition.LeafName)' under command '$($OwnedCommandDefinition.ParentName)' from owner '$($OwnedCommandDefinition.OwnerName)' because it is already owned by '$($parentCommand.OwnerName)'."
    )
}

function Find-GerberOwnedCommandDefinitionByParentAndLeafName {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$OwnedCommandDefinitionList,

        [Parameter(Mandatory)]
        [string]$ParentName,

        [Parameter(Mandatory)]
        [string]$LeafName,

        [string]$ExcludeName
    )

    foreach ($ownedCommand in $OwnedCommandDefinitionList) {
        if (Test-GerberOwnedCommandMatchesParentAndLeaf `
                -OwnedCommandDefinition $ownedCommand `
                -ParentName $ParentName `
                -LeafName $LeafName `
                -ExcludeName $ExcludeName) {
            return $ownedCommand
        }
    }

    return $null
}

function Test-GerberOwnedCommandMatchesParentAndLeaf {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$OwnedCommandDefinition,

        [Parameter(Mandatory)]
        [string]$ParentName,

        [Parameter(Mandatory)]
        [string]$LeafName,

        [string]$ExcludeName
    )

    return ($OwnedCommandDefinition.ParentName -ieq $ParentName) -and
        ($OwnedCommandDefinition.LeafName -ieq $LeafName) -and
        ($OwnedCommandDefinition.Name -ine $ExcludeName)
}

function Get-GerberRegisteredCommandConflictException {
    [OutputType([System.InvalidOperationException])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$OwnedCommandDefinition,

        [Parameter(Mandatory)]
        [pscustomobject]$ExistingCommandDefinition
    )

    if ($OwnedCommandDefinition.ParentName) {
        return [System.InvalidOperationException]::new(
            "Gerber cannot register command '$($OwnedCommandDefinition.Name)' from owner '$($OwnedCommandDefinition.OwnerName)' because it is already owned by '$($ExistingCommandDefinition.OwnerName)'."
        )
    }

    return [System.InvalidOperationException]::new(
        "Gerber cannot register root command '$($OwnedCommandDefinition.Name)' from owner '$($OwnedCommandDefinition.OwnerName)' because it is already owned by '$($ExistingCommandDefinition.OwnerName)'."
    )
}

function Add-GerberOwnedSubcommandDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$RegisteredCommandList,

        [Parameter(Mandatory)]
        [pscustomobject]$OwnedCommandDefinition
    )

    $parentCommand = Find-GerberRegisteredCommandConflict `
        -RegisteredCommandList $RegisteredCommandList `
        -CommandName $OwnedCommandDefinition.ParentName
    $parentCommand.Subcommands[$OwnedCommandDefinition.LeafName] = ConvertTo-GerberCommandCatalogEntry `
        -Description $OwnedCommandDefinition.Description `
        -Subcommands $OwnedCommandDefinition.Subcommands
}
