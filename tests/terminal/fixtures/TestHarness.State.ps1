function Initialize-GerberTerminalFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$Value
    )

    $directoryPath = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directoryPath -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $directoryPath -Force
    }

    $json = $Value | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.Encoding]::UTF8)
}

function Read-GerberTerminalJsonFile {
    [OutputType([object])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$DefaultValue
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Initialize-GerberTerminalFile -Path $Path -Value $DefaultValue
        return $DefaultValue
    }

    return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable)
}

function Write-GerberTerminalJsonFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$Value
    )

    Initialize-GerberTerminalFile -Path $Path -Value $Value
}

function Get-GerberTerminalPathOrEmpty {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ''
    }

    return [System.IO.Path]::GetFullPath($Path)
}

function Add-GerberTerminalDiagnosticEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Kind,

        [hashtable]$Data = @{}
    )

    $state = Read-GerberTerminalJsonFile -Path $Path -DefaultValue @{
        events = @()
    }
    $diagnosticEvent = [ordered]@{
        kind      = $Kind
        timestamp = [datetime]::UtcNow.ToString('o')
    }
    foreach ($key in $Data.Keys) {
        $diagnosticEvent[$key] = $Data[$key]
    }

    $state.events = @($state.events + @([hashtable]$diagnosticEvent))
    Write-GerberTerminalJsonFile -Path $Path -Value $state
}

function Get-GerberTerminalDefaultModuleState {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param()

    return @{
        validationStatus = 'pending'
        failureMessage = ''
        failureStackTrace = ''
        modules = @{}
    }
}

function Get-GerberTerminalDefaultCredentialStoreState {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param()

    return @{
        credentials = @{}
        operations = @()
        failures = @{}
    }
}
