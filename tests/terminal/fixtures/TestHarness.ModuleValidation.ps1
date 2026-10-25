function Add-GerberTerminalModuleRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [hashtable]$Record
    )

    $State.modules[$Name] = $Record
}

function Get-GerberTerminalExpectedModuleRecord {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$ManifestPath
    )

    $manifestData = Import-PowerShellDataFile -LiteralPath $ManifestPath
    return @{
        Name = $Name
        ManifestPath = (Get-GerberTerminalPathOrEmpty -Path $ManifestPath)
        Version = [string]$manifestData.ModuleVersion
    }
}

function Get-GerberTerminalResolvedModuleRecord {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Module
    )

    if ($null -eq $Module) {
        return @{
            Name = ''
            ManifestPath = ''
            Version = ''
        }
    }

    return @{
        Name = [string]$Module.Name
        ManifestPath = (Get-GerberTerminalPathOrEmpty -Path $Module.Path)
        Version = [string]$Module.Version
    }
}

function Add-GerberTerminalModuleValidationRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [hashtable]$Expected,

        [Parameter(Mandatory)]
        [hashtable]$Resolved,

        [Parameter(Mandatory)]
        [string]$ResolutionKind
    )

    Add-GerberTerminalModuleRecord -State $State -Name $Expected.Name -Record @{
        expected = $Expected
        resolved = $Resolved
        resolutionKind = $ResolutionKind
    }
}

function Test-GerberTerminalModuleResolution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Expected,

        [Parameter(Mandatory)]
        [hashtable]$Resolved,

        [Parameter(Mandatory)]
        [string]$ResolutionKind
    )

    if ([string]::IsNullOrWhiteSpace($Resolved.ManifestPath)) {
        throw "Gerber terminal harness could not resolve module '$($Expected.Name)' via $ResolutionKind."
    }

    $expectedModuleRoot = Split-Path -Parent $Expected.ManifestPath
    $resolvedModuleRoot = Split-Path -Parent $Resolved.ManifestPath
    if ($resolvedModuleRoot -ne $expectedModuleRoot) {
        throw "Gerber terminal harness resolved module '$($Expected.Name)' from '$($Resolved.ManifestPath)' instead of expected built module root '$expectedModuleRoot'."
    }

    if ($Resolved.Version -ne $Expected.Version) {
        throw "Gerber terminal harness resolved module '$($Expected.Name)' version '$($Resolved.Version)' instead of expected version '$($Expected.Version)'."
    }
}

function Get-GerberTerminalFirstAvailableModule {
    [OutputType([object])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    return Get-Module -ListAvailable -Name $Name | Select-Object -First 1
}

function Get-GerberTerminalModuleValidationContext {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleStatePath,

        [Parameter(Mandatory)]
        [string]$DiagnosticStatePath
    )

    return @{
        ModuleStatePath = $ModuleStatePath
        DiagnosticStatePath = $DiagnosticStatePath
    }
}

function Add-GerberTerminalResolvedModuleValidation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$ValidationContext,

        [Parameter(Mandatory)]
        [hashtable]$Expected,

        [Parameter(Mandatory)]
        [hashtable]$Resolved,

        [Parameter(Mandatory)]
        [string]$ResolutionKind
    )

    $moduleState = Read-GerberTerminalJsonFile -Path $ValidationContext.ModuleStatePath -DefaultValue (Get-GerberTerminalDefaultModuleState)
    Add-GerberTerminalModuleValidationRecord -State $moduleState -Expected $Expected -Resolved $Resolved -ResolutionKind $ResolutionKind
    Write-GerberTerminalJsonFile -Path $ValidationContext.ModuleStatePath -Value $moduleState
    Add-GerberTerminalDiagnosticEvent -Path $ValidationContext.DiagnosticStatePath -Kind 'module-validated' -Data @{
        moduleName = $Expected.Name
        resolutionKind = $ResolutionKind
        resolvedManifestPath = $Resolved.ManifestPath
        resolvedVersion = $Resolved.Version
    }
}

function Assert-GerberTerminalResolvedModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$ValidationContext,

        [Parameter(Mandatory)]
        [hashtable]$Expected,

        [Parameter(Mandatory)]
        [object]$Module,

        [Parameter(Mandatory)]
        [string]$ResolutionKind
    )

    $resolved = Get-GerberTerminalResolvedModuleRecord -Module $Module
    Test-GerberTerminalModuleResolution -Expected $Expected -Resolved $resolved -ResolutionKind $ResolutionKind
    Add-GerberTerminalResolvedModuleValidation `
        -ValidationContext $ValidationContext `
        -Expected $Expected `
        -Resolved $resolved `
        -ResolutionKind $ResolutionKind
}

function Complete-GerberTerminalModuleValidation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $state = Read-GerberTerminalJsonFile -Path $Path -DefaultValue (Get-GerberTerminalDefaultModuleState)
    $state.validationStatus = 'passed'
    $state.failureMessage = ''
    $state.failureStackTrace = ''
    Write-GerberTerminalJsonFile -Path $Path -Value $state
}

function Write-GerberTerminalModuleValidationFailure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $state = Read-GerberTerminalJsonFile -Path $Path -DefaultValue (Get-GerberTerminalDefaultModuleState)
    $state.validationStatus = 'failed'
    $state.failureMessage = [string]$ErrorRecord.Exception.Message
    $state.failureStackTrace = [string]$ErrorRecord.ScriptStackTrace
    Write-GerberTerminalJsonFile -Path $Path -Value $state
}
