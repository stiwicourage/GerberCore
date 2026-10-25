BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Read-GerberSecureValue' {
    It 'uses the fallback secure prompt when the interactive prompt is unavailable' {
        Mock Clear-GerberPendingConsoleInput {}
        Mock Test-GerberInteractivePromptAvailable { $false }
        Mock Read-Host {
            $secureValue = New-Object System.Security.SecureString
            foreach ($character in 'secret-value'.ToCharArray()) {
                $secureValue.AppendChar($character)
            }

            $secureValue.MakeReadOnly()
            return $secureValue
        } -ParameterFilter { $Prompt -eq 'Azure DevOps PAT' -and $AsSecureString }

        $result = Read-GerberSecureValue -Prompt 'Azure DevOps PAT'

        (ConvertTo-GerberSecretText -Value $result) | Should -Be 'secret-value'
        Should -Invoke Read-Host -Times 1 -ParameterFilter { $Prompt -eq 'Azure DevOps PAT' -and $AsSecureString }
    }

    It 'treats esc text in the fallback secure prompt as back navigation' {
        Mock Clear-GerberPendingConsoleInput {}
        Mock Test-GerberInteractivePromptAvailable { $false }
        Mock Read-Host {
            $secureValue = New-Object System.Security.SecureString
            foreach ($character in 'esc'.ToCharArray()) {
                $secureValue.AppendChar($character)
            }

            $secureValue.MakeReadOnly()
            return $secureValue
        } -ParameterFilter { $Prompt -eq 'Azure DevOps PAT' -and $AsSecureString }

        { Read-GerberSecureValue -Prompt 'Azure DevOps PAT' } | Should -Throw 'Go back to the previous Gerber menu.'
    }

    It 'treats Escape in the interactive secure prompt as back navigation' {
        Mock Clear-GerberPendingConsoleInput {}
        Mock Test-GerberInteractivePromptAvailable { $true }
        Mock Read-GerberMenuConsoleKey { [System.ConsoleKeyInfo]::new([char]27, [System.ConsoleKey]::Escape, $false, $false, $false) }

        { Read-GerberSecureValue -Prompt 'Azure DevOps PAT' } | Should -Throw 'Go back to the previous Gerber menu.'
    }

    It 'classifies secure-prompt keys and detects escape text' {
        (Get-GerberSecureValueKeyAction -Key ([System.ConsoleKeyInfo]::new([char]13, [System.ConsoleKey]::Enter, $false, $false, $false))) | Should -Be 'Submit'
        (Get-GerberSecureValueKeyAction -Key ([System.ConsoleKeyInfo]::new([char]8, [System.ConsoleKey]::Backspace, $false, $false, $false))) | Should -Be 'Backspace'
        (Get-GerberSecureValueKeyAction -Key ([System.ConsoleKeyInfo]::new('a', [System.ConsoleKey]::A, $false, $false, $false))) | Should -Be 'Character'

        $secureValue = New-Object System.Security.SecureString
        foreach ($character in 'escape'.ToCharArray()) {
            $secureValue.AppendChar($character)
        }

        $secureValue.MakeReadOnly()
        (Test-GerberSecureValueEscapeText -Value $secureValue -EscapeTokenList @('esc', 'escape')) | Should -BeTrue
    }

    It 'returns Ignore for key events with no character data' {
        $key = [System.ConsoleKeyInfo]::new([char]0, [System.ConsoleKey]::F1, $false, $false, $false)

        (Get-GerberSecureValueKeyAction -Key $key) | Should -Be 'Ignore'
    }

    It 'seals and returns the accumulated secure value on completion' {
        $secureValue = New-Object System.Security.SecureString
        foreach ($c in 'test'.ToCharArray()) { $secureValue.AppendChar($c) }

        $result = Complete-GerberInteractiveSecureValue -SecureValue $secureValue

        $result.IsReadOnly() | Should -BeTrue
        (ConvertTo-GerberSecretText -Value $result) | Should -Be 'test'
    }

    It 'returns unchanged count when there are no characters to backspace' {
        $secureValue = New-Object System.Security.SecureString

        $result = Invoke-GerberSecureValueBackspace -SecureValue $secureValue -CharacterCount 0

        $result | Should -Be 0
    }

    It 'removes the last character and returns the decremented count' {
        $secureValue = New-Object System.Security.SecureString
        $secureValue.AppendChar('a')

        $result = Invoke-GerberSecureValueBackspace -SecureValue $secureValue -CharacterCount 1

        $result | Should -Be 0
        $secureValue.Length | Should -Be 0
    }

    It 'appends a character to the secure value and increments the count' {
        $secureValue = New-Object System.Security.SecureString
        $key = [System.ConsoleKeyInfo]::new('x', [System.ConsoleKey]::X, $false, $false, $false)

        $result = Add-GerberSecureValueCharacter -SecureValue $secureValue -CharacterCount 0 -Key $key

        $result | Should -Be 1
        $secureValue.Length | Should -Be 1
    }

    It 'handles character, backspace, ignore, and submit actions in the interactive loop' {
        $script:interactiveSecureKeyIndex = 0
        $keySequence = @(
            [System.ConsoleKeyInfo]::new('a', [System.ConsoleKey]::A, $false, $false, $false)
            [System.ConsoleKeyInfo]::new([char]8, [System.ConsoleKey]::Backspace, $false, $false, $false)
            [System.ConsoleKeyInfo]::new([char]0, [System.ConsoleKey]::F1, $false, $false, $false)
            [System.ConsoleKeyInfo]::new([char]13, [System.ConsoleKey]::Enter, $false, $false, $false)
        )
        Mock Read-GerberMenuConsoleKey {
            $key = $keySequence[$script:interactiveSecureKeyIndex]
            $script:interactiveSecureKeyIndex++
            return $key
        }
        $script:interactiveSecureKeyIndex = 0

        $result = Read-GerberInteractiveSecureValue -Prompt 'Test Prompt'

        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeOfType [securestring]
    }
}
