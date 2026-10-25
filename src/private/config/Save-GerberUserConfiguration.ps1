function Save-GerberUserConfiguration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [object]$Configuration
    )

    $configPath = Resolve-GerberUserConfigPath
    $null = Test-GerberUserConfiguration -Configuration $Configuration -Path $configPath
    if (-not $PSCmdlet.ShouldProcess($configPath, 'Save Gerber user configuration')) {
        return
    }

    $configDirectory = Split-Path -Parent $configPath
    if (-not (Test-Path -LiteralPath $configDirectory -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $configDirectory -Force -ErrorAction Stop
    }

    $json = ConvertTo-GerberUserConfigurationJson -Configuration $Configuration
    $tempPath = Get-GerberUserConfigurationTemporaryPath -DestinationPath $configPath
    try {
        Write-GerberUserConfigurationFileContent -Path $tempPath -Content $json
        Protect-GerberUserConfigurationFile -Path $tempPath
        Publish-GerberUserConfigurationTemporaryFile -SourcePath $tempPath -DestinationPath $configPath
    } catch [System.UnauthorizedAccessException] {
        throw [System.UnauthorizedAccessException]::new(
            "Gerber could not save user configuration file '$configPath'. Access was denied.",
            $_.Exception
        )
    } catch [System.IO.IOException] {
        throw [System.IO.IOException]::new(
            "Gerber could not save user configuration file '$configPath'. $($_.Exception.Message)",
            $_.Exception
        )
    } finally {
        Clear-GerberUserConfigurationTemporaryFile -Path $tempPath
    }
}

function ConvertTo-GerberUserConfigurationJson {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Configuration
    )

    return ($Configuration | ConvertTo-Json -Depth 100)
}

function Get-GerberUserConfigurationTemporaryPath {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DestinationPath
    )

    return (Join-Path (Split-Path -Parent $DestinationPath) ([System.IO.Path]::GetRandomFileName() + '.tmp'))
}

function Write-GerberUserConfigurationFileContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Content
    )

    $encoding = [System.Text.UTF8Encoding]::new($false)
    $fileStream = [System.IO.FileStream]::new(
        $Path,
        [System.IO.FileMode]::CreateNew,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::None
    )
    try {
        $writer = [System.IO.StreamWriter]::new($fileStream, $encoding)
        try {
            $writer.Write($Content)
            $writer.Flush()
            $fileStream.Flush($true)
        } finally {
            $writer.Dispose()
        }
    } finally {
        $fileStream.Dispose()
    }
}

function Protect-GerberUserConfigurationFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if ($IsWindows) {
        return
    }

    [System.IO.File]::SetUnixFileMode($Path, [System.IO.UnixFileMode]'UserRead, UserWrite')
}

function Publish-GerberUserConfigurationTemporaryFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$DestinationPath
    )

    if (Test-Path -LiteralPath $DestinationPath -PathType Leaf) {
        if ($IsWindows) {
            [System.IO.File]::Replace($SourcePath, $DestinationPath, $null, $false)
            return
        }

        [System.IO.File]::Move($SourcePath, $DestinationPath, $true)
        return
    }

    [System.IO.File]::Move($SourcePath, $DestinationPath)
}

function Clear-GerberUserConfigurationTemporaryFile {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    }
}
