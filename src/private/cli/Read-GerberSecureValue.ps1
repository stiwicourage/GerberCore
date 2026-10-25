function Read-GerberSecureValue {
    [OutputType([securestring])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [string[]]$EscapeTokenList = @('esc', 'escape')
    )

    Clear-GerberPendingConsoleInput
    if (Test-GerberInteractivePromptAvailable) {
        return Read-GerberInteractiveSecureValue -Prompt $Prompt
    }

    return Read-GerberFallbackSecureValue -Prompt $Prompt -EscapeTokenList $EscapeTokenList
}

function Read-GerberInteractiveSecureValue {
    [OutputType([securestring])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt
    )

    Write-GerberSecureValuePrompt -Prompt $Prompt
    $secureValue = New-Object System.Security.SecureString
    $characterCount = 0
    while ($true) {
        $key = Read-GerberMenuConsoleKey
        $keyAction = Get-GerberSecureValueKeyAction -Key $key
        switch ($keyAction) {
            'Submit' {
                return Complete-GerberInteractiveSecureValue -SecureValue $secureValue
            }
            'Escape' {
                Invoke-GerberInteractiveSecureEscape
            }
            'Backspace' {
                $characterCount = Invoke-GerberSecureValueBackspace -SecureValue $secureValue -CharacterCount $characterCount
                continue
            }
            'Ignore' {
                continue
            }
        }

        $characterCount = Add-GerberSecureValueCharacter -SecureValue $secureValue -CharacterCount $characterCount -Key $key
    }
}

function Read-GerberFallbackSecureValue {
    [OutputType([securestring])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter(Mandatory)]
        [string[]]$EscapeTokenList
    )

    $secureValue = Read-Host -Prompt $Prompt -AsSecureString
    if (Test-GerberSecureValueEscapeText -Value $secureValue -EscapeTokenList $EscapeTokenList) {
        throw (Get-GerberMenuEscapeException)
    }

    return $secureValue
}

function Write-GerberSecureValuePrompt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt
    )

    $Host.UI.Write("$Prompt`: ")
}

function Get-GerberSecureValueKeyAction {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.ConsoleKeyInfo]$Key
    )

    if ($Key.Key -eq [System.ConsoleKey]::Enter) {
        return 'Submit'
    }

    if ($Key.Key -eq [System.ConsoleKey]::Escape) {
        return 'Escape'
    }

    if ($Key.Key -eq [System.ConsoleKey]::Backspace) {
        return 'Backspace'
    }

    if ([int]$Key.KeyChar -eq 0) {
        return 'Ignore'
    }

    return 'Character'
}

function Complete-GerberInteractiveSecureValue {
    [OutputType([securestring])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [securestring]$SecureValue
    )

    $Host.UI.WriteLine()
    $SecureValue.MakeReadOnly()
    return $SecureValue
}

function Invoke-GerberInteractiveSecureEscape {
    [CmdletBinding()]
    param()

    $Host.UI.WriteLine()
    throw (Get-GerberMenuEscapeException)
}

function Invoke-GerberSecureValueBackspace {
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [securestring]$SecureValue,

        [Parameter(Mandatory)]
        [int]$CharacterCount
    )

    if ($CharacterCount -le 0) {
        return $CharacterCount
    }

    $SecureValue.RemoveAt($CharacterCount - 1)
    $Host.UI.Write("`b `b")
    return ($CharacterCount - 1)
}

function Add-GerberSecureValueCharacter {
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [securestring]$SecureValue,

        [Parameter(Mandatory)]
        [int]$CharacterCount,

        [Parameter(Mandatory)]
        [System.ConsoleKeyInfo]$Key
    )

    $SecureValue.AppendChar($Key.KeyChar)
    $Host.UI.Write('*')
    return ($CharacterCount + 1)
}

function Test-GerberSecureValueEscapeText {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [securestring]$Value,

        [Parameter(Mandatory)]
        [string[]]$EscapeTokenList
    )

    return $EscapeTokenList -contains (ConvertTo-GerberSecretText -Value $Value).Trim().ToLowerInvariant()
}
