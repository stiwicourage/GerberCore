function Get-GerberPluginCommandDiagnostic {
    param($Command, $Document, $Contract, [string[]]$OwnedNames)

    $name = Resolve-GerberStaticSourceValue -Node $Command.CommandElements[0]
    $visibleNames = @($OwnedNames) + @(Get-GerberLexicalFunctionName -Node $Command)
    $finding = Get-GerberPrivateCommandFinding -Name $name -Contract $Contract -OwnedNames $visibleNames
    if ($finding) {
        Get-GerberBoundaryDiagnostic -Document $Document -Extent $Command.Extent -Finding $finding
    }
    Get-GerberPluginImportDiagnostic -Command $Command -Document $Document -Name $name
    Get-GerberPluginLookupDiagnostic -Command $Command -Document $Document -Contract $Contract -OwnedNames $visibleNames
}

function Get-GerberLexicalFunctionName {
    param($Node)

    $parent = $Node.Parent
    while ($null -ne $parent) {
        if ($parent -is [System.Management.Automation.Language.ScriptBlockAst]) {
            $definitions = $parent.FindAll({ param($item) $item -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)
            foreach ($definition in $definitions) {
                $definition.Name -replace '^(global:|script:|local:)', ''
            }
        }
        $parent = $parent.Parent
    }
}

function Get-GerberPrivateCommandFinding {
    param([string]$Name, $Contract, [string[]]$OwnedNames)

    $parts = $Name -split '\\', 2
    if (Test-GerberPluginCommandOwnership -Parts $parts -OwnedNames $OwnedNames) {
        return
    }
    $unqualified = $parts[-1]
    if ($Contract.PrivateCommands.ContainsKey($unqualified)) {
        return @{ Dependency = $Name; Reason = 'PrivateCoreCommand'; Resolution = $Contract.PrivateCommands[$unqualified] }
    }
}

function Test-GerberPluginCommandOwnership {
    param([string[]]$Parts, [string[]]$OwnedNames)

    if ($Parts.Count -eq 1) {
        return $Parts[0] -in $OwnedNames
    }
    return $Parts[0] -ne 'Gerber'
}

function Get-GerberPluginLookupDiagnostic {
    param($Command, $Document, $Contract, [string[]]$OwnedNames)

    $name = $Command.GetCommandName() -replace '^Microsoft.PowerShell.Core\\', ''
    if ($name -notin @('Get-Command', 'gcm', 'Invoke-Expression', 'iex')) {
        return
    }
    foreach ($target in (Get-GerberLookupCommandTarget -Command $Command -Name $name)) {
        Write-GerberPrivateLookupDiagnostic -Target $target -Command $Command -Document $Document -Context @{
            Contract = $Contract; OwnedNames = $OwnedNames
        }
    }
}

function Get-GerberLookupCommandTarget {
    param($Command, [string]$Name)

    $moduleName = Get-GerberLookupModuleName -Command $Command
    foreach ($argument in $Command.CommandElements | Select-Object -Skip 1) {
        $value = Resolve-GerberStaticSourceValue -Node $argument
        Get-GerberLiteralLookupTarget -Name $Name -Value $value -ModuleName $moduleName
    }
}

function Get-GerberLiteralLookupTarget {
    param([string]$Name, [string]$Value, [string]$ModuleName)

    if ($Name -in @('Get-Command', 'gcm')) {
        return Get-GerberModuleLookupTarget -Value $Value -ModuleName $ModuleName
    }
    $tree = [System.Management.Automation.Language.Parser]::ParseInput($Value, [ref]$null, [ref]$null)
    $calls = $tree.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true)
    foreach ($call in $calls) {
        Resolve-GerberStaticSourceValue -Node $call.CommandElements[0]
    }
}

function Get-GerberLookupModuleName {
    param($Command)

    $parameter = $Command.CommandElements | Where-Object {
        $_ -is [System.Management.Automation.Language.CommandParameterAst] -and $_.ParameterName -eq 'Module'
    } | Select-Object -First 1
    if ($null -eq $parameter) {
        return
    }
    if ($parameter.Argument) {
        return Resolve-GerberStaticSourceValue -Node $parameter.Argument
    }
    $index = [array]::IndexOf([object[]]$Command.CommandElements, $parameter) + 1
    return Resolve-GerberStaticSourceValue -Node ($Command.CommandElements | Select-Object -Index $index)
}

function Get-GerberModuleLookupTarget {
    param([string]$Value, [string]$ModuleName)

    if ($ModuleName -eq 'Gerber') {
        return "Gerber\$Value"
    }
    if ([string]::IsNullOrEmpty($ModuleName)) {
        return $Value
    }
}

function Write-GerberPrivateLookupDiagnostic {
    param([string]$Target, $Command, $Document, $Context)

    $finding = Get-GerberPrivateCommandFinding -Name $Target -Contract $Context.Contract -OwnedNames $Context.OwnedNames
    if ($finding) {
        Get-GerberBoundaryDiagnostic -Document $Document -Extent $Command.Extent -Finding $finding
    }
}
