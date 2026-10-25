function Get-GerberMenuSubcommand {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName,

        [Parameter(Mandatory)]
        [pscustomobject]$Command,

        [System.Collections.IDictionary]$SubcommandTable,

        [switch]$AutoSelectFirstSuggestionOnSubmit
    )

    $resolvedSubcommandTable = if ($null -eq $SubcommandTable) {
        Get-GerberMenuSubcommandTable -CommandName $CommandName
    } else {
        $SubcommandTable
    }
    [object[]]$argumentList = if ($null -eq $Command.Arguments) { @() } else { @($Command.Arguments) }
    $inputText = if ((Get-GerberCollectionCount -InputObject $argumentList) -gt 0) {
        $argumentList[0]
    } else {
        try {
            $promptParameters = @{
                CommandName = $CommandName
                SubcommandTable = $resolvedSubcommandTable
                AutoSelectFirstSuggestionOnSubmit = $AutoSelectFirstSuggestionOnSubmit
            }

            Read-GerberSubcommandPrompt @promptParameters
        } catch {
            if (Test-GerberTopLevelMenuEscapeRequest -CommandName $CommandName -Exception $_.Exception) {
                Request-GerberVisibleRootPrompt
            }

            throw
        }
    }

    return Resolve-GerberMenuSubcommandInput -CommandName $CommandName -InputText $inputText
}

function Test-GerberTopLevelMenuEscapeRequest {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName,

        [AllowNull()]
        [System.Exception]$Exception
    )

    if ($CommandName.Contains(' ')) {
        return $false
    }

    return Test-GerberMenuEscapeException -Exception $Exception
}

function Resolve-GerberMenuSubcommandInput {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName,

        [string]$InputText
    )

    $normalized = $InputText.Trim().ToLowerInvariant()
    $commandPrefix = "/$CommandName"
    if ($normalized.StartsWith("$commandPrefix ")) {
        return $normalized.Substring($commandPrefix.Length).Trim()
    }

    if ($normalized -eq $commandPrefix) {
        return ''
    }

    if ($normalized.StartsWith('/')) {
        return $normalized.TrimStart('/')
    }

    return $normalized
}
