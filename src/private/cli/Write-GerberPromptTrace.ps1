function Test-GerberPromptTraceEnabled {
    [OutputType([bool])]
    [CmdletBinding()]
    param()

    $traceValue = [Environment]::GetEnvironmentVariable('GERBER_PROMPT_TRACE')
    if ([string]::IsNullOrWhiteSpace($traceValue)) {
        return $false
    }

    return @('1', 'true', 'on', 'yes') -contains $traceValue.Trim().ToLowerInvariant()
}

function Resolve-GerberPromptTracePath {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    return Join-Path (Split-Path -Parent (Resolve-GerberConfigPath)) 'prompt-debug.log'
}

function Write-GerberPromptTrace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EventName,

        [Parameter(Mandatory)]
        [hashtable]$Data
    )

    if (-not (Test-GerberPromptTraceEnabled)) {
        return
    }

    try {
        $tracePath = Resolve-GerberPromptTracePath
        $traceDirectory = Split-Path -Parent $tracePath
        if (-not (Test-Path -LiteralPath $traceDirectory -PathType Container)) {
            $null = New-Item -ItemType Directory -Path $traceDirectory -Force -ErrorAction Stop
        }

        $payload = [ordered]@{
            Timestamp = (Get-Date).ToString('o')
            SessionId = Get-GerberPromptTraceSessionId
            Event     = $EventName
            Data      = $Data
        }
        Add-Content -LiteralPath $tracePath -Value ($payload | ConvertTo-Json -Depth 5 -Compress) -ErrorAction Stop
    } catch {
        return
    }
}

function Get-GerberPromptKeyTraceData {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.ConsoleKeyInfo]$Key,

        [Parameter(Mandatory)]
        [hashtable]$State
    )

    return @{
        Buffer = $State.Buffer
        CursorIndex = $State.CursorIndex
        Key = $Key.Key.ToString()
        KeyChar = [int][char]$Key.KeyChar
        Character = [string]$Key.KeyChar
        Modifiers = $Key.Modifiers.ToString()
    }
}

function Get-GerberPromptTraceSessionId {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    $sessionIdVariable = Get-Variable `
        -Name 'GerberPromptTraceSessionId' `
        -Scope Script `
        -ErrorAction SilentlyContinue
    if ($null -eq $sessionIdVariable -or [string]::IsNullOrWhiteSpace([string]$sessionIdVariable.Value)) {
        $script:GerberPromptTraceSessionId = [guid]::NewGuid().ToString()
    }

    return $script:GerberPromptTraceSessionId
}
