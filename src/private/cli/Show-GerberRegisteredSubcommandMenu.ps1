function Show-GerberRegisteredSubcommandMenu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName,

        [Parameter(Mandatory)]
        [pscustomobject]$Command,

        [switch]$AutoSelectFirstSuggestionOnSubmit
    )

    $currentCommand = $Command
    while ($true) {
        $selectionParameters = @{
            CommandName = $CommandName
            Command = $currentCommand
            AutoSelectFirstSuggestionOnSubmit = $AutoSelectFirstSuggestionOnSubmit
        }

        $subcommand = Get-GerberRegisteredSubcommandSelection @selectionParameters
        if ([string]::IsNullOrWhiteSpace($subcommand)) {
            return
        }

        $registeredCommand = Get-GerberRegisteredSubcommandDefinition -CommandName $CommandName -Subcommand $subcommand
        Invoke-GerberRegisteredSubcommand `
            -RegisteredCommand $registeredCommand `
            -Arguments $currentCommand.Arguments
        $currentCommand = ConvertTo-GerberNestedCommand
    }
}

function Get-GerberRegisteredSubcommandSelection {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName,

        [Parameter(Mandatory)]
        [pscustomobject]$Command,

        [switch]$AutoSelectFirstSuggestionOnSubmit
    )

    try {
        return Get-GerberMenuSubcommand `
            -CommandName $CommandName `
            -Command $Command `
            -AutoSelectFirstSuggestionOnSubmit:$AutoSelectFirstSuggestionOnSubmit
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) {
            return ''
        }

        throw
    }
}

function Get-GerberRegisteredSubcommandDefinition {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName,

        [Parameter(Mandatory)]
        [string]$Subcommand
    )

    $registeredCommand = Get-GerberRegisteredCommand -Name "$CommandName $Subcommand"
    if ($null -ne $registeredCommand) {
        return $registeredCommand
    }

    throw [System.ArgumentException]::new(
        "Unknown subcommand '$Subcommand' for '/$CommandName'."
    )
}

function Invoke-GerberRegisteredSubcommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$RegisteredCommand,

        [AllowEmptyCollection()]
        [string[]]$Arguments = @()
    )

    try {
        $nestedCommand = ConvertTo-GerberNestedCommand -Arguments $Arguments -SkipCount 1
        $null = Invoke-GerberRegisteredCommand -CommandDefinition $RegisteredCommand -Command $nestedCommand
    } catch {
        if (-not (Test-GerberMenuEscapeException -Exception $_.Exception)) {
            throw
        }
    }
}
