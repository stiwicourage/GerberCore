function Get-GerberPluginBoundaryResult {
    param([string]$Path, [pscustomobject]$Contract)

    $root = (Get-Item -LiteralPath $Path -ErrorAction Stop).FullName
    $files = @(Get-GerberPluginAuthoredSource -Root $root)
    $documents = @($files | ForEach-Object { Read-GerberPluginSourceDocument -File $_ -Root $root })
    $ownedNames = @(Get-GerberPluginOwnedFunctionName -Documents $documents)
    $diagnostics = @($documents | ForEach-Object {
        Get-GerberPluginDocumentDiagnostic -Document $_ -Contract $Contract -OwnedNames $ownedNames
    })
    return ConvertTo-GerberBoundaryResult -Diagnostics $diagnostics -FileCount $files.Count -PublicApi $Contract.PublicApi
}

function ConvertTo-GerberBoundaryResult {
    param([object[]]$Diagnostics, [int]$FileCount, $PublicApi)

    return [pscustomobject][ordered]@{
        IsValid = $Diagnostics.Count -eq 0
        FileCount = $FileCount
        PublicApi = $PublicApi
        Diagnostics = @($Diagnostics | Sort-Object File, Line, Column, Reason, Dependency -Unique)
    }
}

function Get-GerberPluginAuthoredSource {
    param([string]$Root)

    Assert-GerberPluginSourceDirectory -Root $Root
    $files = @(Get-ChildItem -LiteralPath $Root -File)
    foreach ($directory in @('src', 'scripts')) {
        $path = Join-Path $Root $directory
        if (Test-Path -LiteralPath $path -PathType Container) {
            $files += Get-ChildItem -LiteralPath $path -Recurse -File
        }
    }
    return $files |
        Where-Object Extension -In @('.ps1', '.psm1', '.psd1') |
        Sort-Object FullName
}

function Assert-GerberPluginSourceDirectory {
    param([string]$Root)

    $source = Join-Path $Root 'src'
    if (-not (Test-Path -LiteralPath $source -PathType Container)) {
        throw [System.IO.DirectoryNotFoundException]::new("Plugin authored source directory '$source' does not exist.")
    }
}

function Read-GerberPluginSourceDocument {
    param([System.IO.FileInfo]$File, [string]$Root)

    $parseErrors = $null
    $tree = [System.Management.Automation.Language.Parser]::ParseFile($File.FullName, [ref]$null, [ref]$parseErrors)
    return [pscustomobject]@{
        Tree = $tree
        File = [System.IO.Path]::GetRelativePath($Root, $File.FullName).Replace('\', '/')
        ParseErrors = @($parseErrors)
    }
}

function Get-GerberPluginOwnedFunctionName {
    param([object[]]$Documents)

    foreach ($document in $Documents) {
        $functions = $document.Tree.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)
        foreach ($definition in $functions) {
            $definition.Name -replace '^(global:|script:|local:)', ''
        }
    }
}

function Get-GerberPluginDocumentDiagnostic {
    param($Document, $Contract, [string[]]$OwnedNames)

    foreach ($parseError in $Document.ParseErrors) {
        Get-GerberBoundaryDiagnostic -Document $Document -Extent $parseError.Extent -Finding @{
            Dependency = $parseError.ErrorId; Reason = 'ParseError'; Resolution = "Fix PowerShell syntax: $($parseError.Message)"
        }
    }
    $commands = $Document.Tree.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true)
    foreach ($command in $commands) {
        Get-GerberPluginCommandDiagnostic -Command $command -Document $Document -Contract $Contract -OwnedNames $OwnedNames
    }
    Get-GerberPluginUsingDiagnostic -Document $Document
}
