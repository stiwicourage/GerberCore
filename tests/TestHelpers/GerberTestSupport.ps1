function Get-GerberProjectRoot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StartPath
    )

    $currentPath = [System.IO.Path]::GetFullPath($StartPath)
    while (-not (Test-Path -LiteralPath (Join-Path $currentPath 'project.json') -PathType Leaf)) {
        $parentPath = Split-Path -Parent $currentPath
        if ($parentPath -eq $currentPath) {
            throw "Could not locate project.json from '$StartPath'."
        }

        $currentPath = $parentPath
    }

    return $currentPath
}

function Import-GerberSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StartPath
    )

    $projectRoot = Get-GerberProjectRoot -StartPath $StartPath
    $privateFileList = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'src/private') -Recurse -File -Filter '*.ps1' | Sort-Object FullName
    $publicFileList = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'src/public') -File -Filter '*.ps1' | Sort-Object FullName
    foreach ($file in @($privateFileList + $publicFileList)) {
        $functionNameList = Get-GerberFunctionNameList -Path $file.FullName
        . $file.FullName
        foreach ($functionName in $functionNameList) {
            $scriptBlock = (Get-Command $functionName -CommandType Function).ScriptBlock
            Set-Item -Path "function:global:$functionName" -Value $scriptBlock
        }
    }

    if (Get-Command -Name 'Clear-GerberCommandRegistry' -ErrorAction SilentlyContinue) {
        Clear-GerberCommandRegistry
    }

    if (Get-Command -Name 'Initialize-GerberCommandRegistry' -ErrorAction SilentlyContinue) {
        $null = Initialize-GerberCommandRegistry -PluginModulePathList @()
    }
}

function Get-GerberFunctionNameList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    return @(
        foreach ($match in [regex]::Matches((Get-Content -LiteralPath $Path -Raw), '(?m)^function\s+([A-Za-z0-9\-_]+)\s*\{')) {
            $match.Groups[1].Value
        }
    )
}

function Get-GerberPluginFixtureModulePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StartPath
    )

    $projectRoot = Get-GerberProjectRoot -StartPath $StartPath
    return (Join-Path $projectRoot 'tests/fixtures/Modules')
}

function Reset-GerberPluginTestEnvironment {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess('Gerber plugin test environment', 'Reset')) {
        Get-Module -Name 'Gerber.*Plugin*', 'NonGerber.TestModule' | Remove-Module -Force -ErrorAction SilentlyContinue
        if (Get-Command -Name 'Clear-GerberCommandRegistry' -ErrorAction SilentlyContinue) {
            Clear-GerberCommandRegistry
        }
    }
}

function New-GerberPluginFixtureModuleRoot {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$StartPath,

        [Parameter(Mandatory)]
        [string[]]$ModuleNameList
    )

    $fixtureModulePath = Get-GerberPluginFixtureModulePath -StartPath $StartPath
    $isolatedRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    if ($PSCmdlet.ShouldProcess($isolatedRoot, 'Create isolated plugin fixture module root')) {
        $null = New-Item -ItemType Directory -Path $isolatedRoot -Force
        foreach ($moduleName in $ModuleNameList) {
            Copy-Item `
                -LiteralPath (Join-Path $fixtureModulePath $moduleName) `
                -Destination (Join-Path $isolatedRoot $moduleName) `
                -Recurse `
                -Force
        }
    }

    return $isolatedRoot
}

function Remove-GerberPluginFixtureModuleRoot {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if ($PSCmdlet.ShouldProcess($Path, 'Remove isolated plugin fixture module root')) {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}
