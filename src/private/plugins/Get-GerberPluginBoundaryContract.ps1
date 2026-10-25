function Get-GerberPluginBoundaryContract {
    $module = $MyInvocation.MyCommand.Module
    $sourceRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
    $files = @(Get-GerberCoreBoundarySource -Module $module -SourceRoot $sourceRoot)
    $publicNames = @(Get-GerberCorePublicName -Module $module -SourceRoot $sourceRoot)
    $api = New-GerberPluginApiContext -ApiVersion '1' -PluginId ([guid]::Empty)
    $capabilities = Get-GerberPublicCapabilityMap -Api $api
    $privateCommands = @{}
    foreach ($name in (Get-GerberCoreFunctionName -Files $files)) {
        if ($name -notin $publicNames) {
            $privateCommands[$name] = Get-GerberBoundaryResolution -Name $name -Capabilities $capabilities
        }
    }
    return [pscustomobject]@{ PrivateCommands = $privateCommands; PublicApi = $capabilities.Names }
}

function Get-GerberCoreBoundarySource {
    param($Module, [string]$SourceRoot)

    if ($null -ne $Module) {
        return $Module.Path
    }
    return (Get-ChildItem -LiteralPath (Join-Path $SourceRoot 'private') -Filter '*.ps1' -File -Recurse).FullName
}

function Get-GerberCorePublicName {
    param($Module, [string]$SourceRoot)

    if ($null -ne $Module) {
        return $Module.ExportedFunctions.Keys
    }
    $files = (Get-ChildItem -LiteralPath (Join-Path $SourceRoot 'public') -Filter '*.ps1' -File).FullName
    return Get-GerberCoreFunctionName -Files $files
}

function Get-GerberCoreFunctionName {
    param([string[]]$Files)

    foreach ($file in $Files) {
        $tree = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$null, [ref]$null)
        $tree.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true).Name
    }
}

function Get-GerberPublicCapabilityMap {
    param([pscustomobject]$Api)

    $names = [ordered]@{}
    $commands = @{}
    foreach ($group in $Api.PSObject.Properties | Where-Object Value -Is [pscustomobject]) {
        $names[$group.Name] = @($group.Value.PSObject.Properties.Name | Sort-Object)
        foreach ($operation in $group.Value.PSObject.Properties) {
            Add-GerberCapabilityCommandMap -Commands $commands -Operation $operation -Group $group.Name
        }
    }
    return [pscustomobject]@{ Names = [pscustomobject]$names; Commands = $commands }
}

function Add-GerberCapabilityCommandMap {
    param([hashtable]$Commands, $Operation, [string]$Group)

    $calls = $Operation.Value.Ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true)
    foreach ($call in $calls) {
        $name = $call.GetCommandName()
        if ($name) {
            $Commands[$name] = '$Gerber.' + $Group + '.' + $Operation.Name
        }
    }
}

function Get-GerberBoundaryResolution {
    param([string]$Name, $Capabilities)

    if ($Capabilities.Commands.ContainsKey($Name)) {
        return "Use the supplied public API v1 operation $($Capabilities.Commands[$Name]) instead."
    }
    return "No public API v1 equivalent is declared for $Name. Request a public capability instead of importing Core internals."
}
