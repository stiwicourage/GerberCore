BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

function script:Set-GerberRepeatedSecretsSubcommandMock {
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [string]$CounterName
    )

    $script:repeatedSecretsAction = $Action
    $script:repeatedSecretsCounterName = $CounterName
    Set-Variable -Scope Script -Name $CounterName -Value 0
    Mock Get-GerberMenuSubcommand {
        $index = Get-Variable -Scope Script -Name $script:repeatedSecretsCounterName -ValueOnly
        Set-Variable -Scope Script -Name $script:repeatedSecretsCounterName -Value ($index + 1)
        return @($script:repeatedSecretsAction, '')[$index]
    }
}

function script:Set-GerberSecretRevealConfirmationMock {
    Mock Get-GerberMenuSubcommand { @('get', '')[$script:getCall++] }
    Mock Use-GerberCredentialStore { $true }
    Mock Clear-Host {}
    Mock Write-GerberScreenLine {}
    Mock Read-GerberCommand { 'gerber:tools:http:token:github' }
    Mock Get-GerberCredentialInfo {
        return @([pscustomobject]@{ Identifier = 'gerber:tools:http:token:github' })
    }
    Mock Test-GerberCredential { $true }
    Mock Get-GerberCredential { 'super-secret-value' }
    Mock Show-GerberTextBlock {}
    Mock Wait-GerberContinue {}
    $script:getCall = 0
}

function script:Assert-GerberSecretRevealConfirmationFlow {
    Should -Invoke Read-GerberCommand -Times 1 -ParameterFilter {
        $Prompt -eq 'Gerber secret name' -and
        $SuggestionMode -eq 'None' -and
        -not $PSBoundParameters.ContainsKey('PromptContext')
    }
    Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter {
        $Text -eq 'Stored Gerber keys'
    }
    Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter {
        $Text -eq 'gerber:tools:http:token:github'
    }
    Should -Invoke Read-GerberConfirmationPrompt -Times 1 -ParameterFilter {
        $Prompt -eq "Reveal 'gerber:tools:http:token:github' in the terminal?" -and
        $PromptOptionSet.ActionPreviewText -eq 'The secret value is already in the clipboard. Reveal it in the terminal too.' -and
        $PromptOptionSet.CancelPreviewText -eq 'Keep the secret hidden in the terminal. The clipboard already contains the secret value.'
    }
    Should -Invoke Copy-GerberValueToClipboard -Times 1 -ParameterFilter {
        $Value -eq 'super-secret-value'
    }
    Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter {
        $Title -eq '/secrets get' -and
        $Text -match 'super-secret-value' -and
        $Text -match 'Gerber already copied the secret value to the clipboard.'
    }
}

Describe 'Show-GerberSecretsView' {
    It 'lists Gerber credential identifiers without secret values' {
        Mock Get-GerberMenuSubcommand { @('list', '')[$script:listCall++] }
        Mock Use-GerberCredentialStore { $true }
        Mock Get-GerberCredentialInfo {
            @([pscustomobject]@{
                    Identifier = 'gerber:tools:base-64:text:test'
                })
        }
        Mock Show-GerberTextBlock {}
        Mock Wait-GerberContinue {}
        $script:listCall = 0

        Show-GerberSecretsView -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter {
            $Title -eq '/secrets list' -and
            $Text -match 'gerber:tools:base-64:text:test' -and
            $Text -notmatch 'Devlooped|CredentialManager' -and
            $Text -notmatch 'secret-value'
        }
    }

    It 'reveals a stored secret only after confirmation' {
        Set-GerberSecretRevealConfirmationMock
        $script:secretCopiedBeforeConfirm = $false
        Mock Read-GerberConfirmationPrompt {
            if (-not $script:secretCopiedBeforeConfirm) {
                throw 'Clipboard copy must happen before the reveal confirmation.'
            }

            return $true
        }
        Mock Copy-GerberValueToClipboard {
            $script:secretCopiedBeforeConfirm = $true
            return [pscustomobject]@{ Success = $true; Message = 'Copied the result to the clipboard.' }
        }

        Show-GerberSecretsView -Command ([pscustomobject]@{ Arguments = @() })

        Assert-GerberSecretRevealConfirmationFlow
    }

    It 'copies the secret to the clipboard and keeps it hidden when reveal is declined' {
        Mock Get-GerberMenuSubcommand { @('get', '')[$script:cancelGetCall++] }
        Mock Use-GerberCredentialStore { $true }
        Mock Clear-Host {}
        Mock Write-GerberScreenLine {}
        Mock Read-GerberCommand { 'gerber:tools:http:token:github' }
        Mock Get-GerberCredentialInfo {
            return @([pscustomobject]@{ Identifier = 'gerber:tools:http:token:github' })
        }
        Mock Test-GerberCredential { $true }
        Mock Read-GerberConfirmationPrompt { $false }
        Mock Get-GerberCredential { 'super-secret-value' }
        Mock Copy-GerberValueToClipboard { [pscustomobject]@{ Success = $true; Message = 'Copied the result to the clipboard.' } }
        Mock Show-GerberTextBlock {}
        Mock Wait-GerberContinue {}
        $script:cancelGetCall = 0

        Show-GerberSecretsView -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Copy-GerberValueToClipboard -Times 1 -ParameterFilter {
            $Value -eq 'super-secret-value'
        }
        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter {
            $Title -eq '/secrets get' -and
            $Text -match 'Gerber kept the secret value hidden in the terminal.' -and
            $Text -match 'Gerber already copied the secret value to the clipboard.' -and
            $Text -notmatch 'super-secret-value'
        }
    }

    It 'asks before overwriting an existing secret' {
        Mock Get-GerberMenuSubcommand { @('set', '')[$script:setCall++] }
        Mock Use-GerberCredentialStore { $true }
        Mock Read-GerberCommand { 'gerber:tools:http:token:github' }
        Mock Test-GerberCredential { $true }
        Mock Read-GerberConfirmationPrompt { $true }
        Mock Read-GerberSecureValue {
            $secureValue = New-Object System.Security.SecureString
            foreach ($character in 'new-secret'.ToCharArray()) {
                $secureValue.AppendChar($character)
            }

            $secureValue.MakeReadOnly()
            return $secureValue
        }
        Mock Set-GerberCredential {}
        Mock Show-GerberTextBlock {}
        Mock Wait-GerberContinue {}
        $script:setCall = 0

        Show-GerberSecretsView -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Read-GerberConfirmationPrompt -Times 1 -ParameterFilter {
            $Prompt -eq "Overwrite 'gerber:tools:http:token:github'?"
        }
        Should -Invoke Set-GerberCredential -Times 1 -ParameterFilter {
            $Identifier -eq 'gerber:tools:http:token:github' -and
            $Secret -eq 'new-secret'
        }
    }

    It 'shows the stored secrets and uses an empty name prompt for remove' {
        Mock Get-GerberMenuSubcommand { @('remove', '')[$script:removeCall++] }
        Mock Use-GerberCredentialStore { $true }
        Mock Clear-Host {}
        Mock Write-GerberScreenLine {}
        Mock Read-GerberCommand { 'gerber:tools:http:token:github' }
        Mock Get-GerberCredentialInfo {
            return @([pscustomobject]@{ Identifier = 'gerber:tools:http:token:github' })
        }
        Mock Test-GerberCredential { $true }
        Mock Read-GerberConfirmationPrompt { $false }
        Mock Show-GerberTextBlock {}
        Mock Wait-GerberContinue {}
        $script:removeCall = 0

        Show-GerberSecretsView -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter {
            $Text -eq 'Stored Gerber keys'
        }
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter {
            $Text -eq 'gerber:tools:http:token:github'
        }
        Should -Invoke Read-GerberCommand -Times 1 -ParameterFilter {
            $Prompt -eq 'Gerber secret name' -and
            $SuggestionMode -eq 'None' -and
            -not $PSBoundParameters.ContainsKey('PromptContext')
        }
        Should -Invoke Read-GerberConfirmationPrompt -Times 1 -ParameterFilter {
            $Prompt -eq "Remove 'gerber:tools:http:token:github'?"
        }
    }

    It 'shows only Gerber credential identifiers in the list view' {
        Mock Get-GerberMenuSubcommand { @('list', '')[$script:keyHeadingListCall++] }
        Mock Use-GerberCredentialStore { $true }
        Mock Get-GerberCredentialInfo {
            @([pscustomobject]@{
                    Identifier = 'gerber:tools:base-64:text:test'
                })
        }
        Mock Show-GerberTextBlock {}
        Mock Wait-GerberContinue {}
        $script:keyHeadingListCall = 0

        Show-GerberSecretsView -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter {
            $Title -eq '/secrets list' -and
            $Text -match '^Stored Gerber credentials' -and
            $Text -match 'gerber:tools:base-64:text:test' -and
            $Text -notmatch '\['
        }
    }

    It 'preloads the required Gerber secret name template and places the cursor at the first placeholder when requested' {
        Mock Read-GerberCommand { 'gerber:tools:http:type:github' }

        $result = Read-GerberOwnedSecretName -Prompt 'Gerber secret name' -PreloadTemplate

        $result | Should -Be 'gerber:tools:http:type:github'
        Should -Invoke Read-GerberCommand -Times 1 -ParameterFilter {
            $Prompt -eq 'Gerber secret name' -and
            $SuggestionMode -eq 'None' -and
            $PromptContext.InitialBuffer -eq 'gerber:<scope>:<name>' -and
            $PromptContext.InitialCursorIndex -eq 7
        }
    }

    It 'shows the canonical identifier template in invalid-name guidance' {
        Mock Read-GerberCommand { 'test' }

        { Read-GerberOwnedSecretName -Prompt 'Gerber secret name' } | Should -Throw "*gerber:<scope>:<name>*"
    }

    It 'returns to the secrets chooser after continue for list' {
        Mock Get-GerberMenuSubcommand { @('list', '')[$script:continueMenuCall++] }
        Mock Use-GerberCredentialStore { $true }
        Mock Get-GerberCredentialInfo { @() }
        Mock Show-GerberTextBlock {}
        Mock Wait-GerberContinue {}
        $script:continueMenuCall = 0

        Show-GerberSecretsView -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Get-GerberMenuSubcommand -Times 2 -ParameterFilter {
            $CommandName -eq 'secrets' -and
            $Command.Arguments.Count -eq 0
        }
    }

    It 'returns immediately when Escape is pressed at the secrets action prompt' {
        Mock Get-GerberMenuSubcommand { throw (Get-GerberMenuEscapeException) }
        Mock Invoke-GerberSecretsAction {}

        Show-GerberSecretsView -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Invoke-GerberSecretsAction -Times 0
    }

    It 'routes argument-error recovery to the expected secrets chooser state' -ForEach @(
        @{
            Name = 'resets to the secrets chooser when continue is escaped after an argument error'
            WaitThrowsEscape = $true
            ExpectedArguments = @()
            CounterName = 'secretErrorCall'
        }
        @{
            Name = 'keeps the current secrets action when continue succeeds after an argument error'
            WaitThrowsEscape = $false
            ExpectedArguments = @('set')
            CounterName = 'stickySecretErrorCall'
        }
    ) {
        $script:expectedSecretsArguments = $ExpectedArguments
        Set-GerberRepeatedSecretsSubcommandMock -Action 'set' -CounterName $CounterName
        Mock Invoke-GerberSecretsAction { throw [System.ArgumentException]::new('Bad secret name.') }
        Mock Show-GerberTextBlock {}
        if ($WaitThrowsEscape) {
            Mock Wait-GerberContinue { throw (Get-GerberMenuEscapeException) }
        } else {
            Mock Wait-GerberContinue {}
        }

        Show-GerberSecretsView -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Get-GerberMenuSubcommand -Times 1 -ParameterFilter {
            $CommandName -eq 'secrets' -and
            ($Command.Arguments -join ',') -eq ($script:expectedSecretsArguments -join ',')
        }
    }

    It 'resets to the secrets chooser when a nested action raises Escape' {
        Mock Get-GerberMenuSubcommand { @('get', '')[$script:secretEscapeCall++] }
        Mock Invoke-GerberSecretsAction { throw (Get-GerberMenuEscapeException) }
        $script:secretEscapeCall = 0

        Show-GerberSecretsView -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Get-GerberMenuSubcommand -Times 2 -ParameterFilter {
            $CommandName -eq 'secrets' -and
            $Command.Arguments.Count -eq 0
        }
    }

    It 'treats unknown secrets actions as errors' {
        { Invoke-GerberSecretsAction -Action 'oops' } |
            Should -Throw "Unknown secrets action 'oops'. Use /secrets list, get, test, set, or remove."
    }

    It 'rejects blank secret names as non-Gerber-owned' {
        (Test-GerberOwnedSecretName -Name '   ') | Should -BeFalse
    }

    It 'throws when the requested Gerber secret is not stored' {
        Mock Test-GerberCredential { $false }

        { Assert-GerberStoredSecret -Name 'gerber:tools:http:token:github' } |
            Should -Throw "*did not find credential 'gerber:tools:http:token:github' in secure credential storage*"
    }

    It 'leaves the existing secret unchanged when overwrite is declined' {
        Mock Get-GerberMenuSubcommand { @('set', '')[$script:declineSetCall++] }
        Mock Use-GerberCredentialStore { $true }
        Mock Read-GerberCommand { 'gerber:tools:http:token:github' }
        Mock Test-GerberCredential { $true }
        Mock Read-GerberConfirmationPrompt { $false }
        Mock Read-GerberSecureValue {}
        Mock Set-GerberCredential {}
        Mock Show-GerberTextBlock {}
        Mock Wait-GerberContinue {}
        $script:declineSetCall = 0

        Show-GerberSecretsView -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Set-GerberCredential -Times 0
        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter {
            $Title -eq '/secrets set' -and
            $Text -eq 'Gerber left the existing secret unchanged.'
        }
    }

    It 'shows a dedicated message when there are no stored secrets for guarded actions' -ForEach @(
        @{
            Name = 'get'
            CounterName = 'noGetSecretsCall'
            ExpectedTitle = '/secrets get'
        }
        @{
            Name = 'remove'
            CounterName = 'noRemoveSecretsCall'
            ExpectedTitle = '/secrets remove'
        }
    ) {
        $script:expectedSecretsEmptyStateTitle = $ExpectedTitle
        Set-GerberRepeatedSecretsSubcommandMock -Action $Name -CounterName $CounterName
        Mock Use-GerberCredentialStore { $true }
        Mock Get-GerberCredentialInfo { @() }
        Mock Show-GerberTextBlock {}
        Mock Wait-GerberContinue {}

        Show-GerberSecretsView -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter {
            $Title -eq $script:expectedSecretsEmptyStateTitle -and
            $Text -eq 'No Gerber-owned credentials are stored.'
        }
    }

    It 'removes a stored secret after confirmation' {
        Mock Get-GerberMenuSubcommand { @('remove', '')[$script:confirmedRemoveCall++] }
        Mock Use-GerberCredentialStore { $true }
        Mock Clear-Host {}
        Mock Write-GerberScreenLine {}
        Mock Read-GerberCommand { 'gerber:tools:http:token:github' }
        Mock Get-GerberCredentialInfo {
            return @([pscustomobject]@{ Identifier = 'gerber:tools:http:token:github' })
        }
        Mock Test-GerberCredential { $true }
        Mock Read-GerberConfirmationPrompt { $true }
        Mock Remove-GerberCredential {}
        Mock Show-GerberTextBlock {}
        Mock Wait-GerberContinue {}
        $script:confirmedRemoveCall = 0

        Show-GerberSecretsView -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Remove-GerberCredential -Times 1 -ParameterFilter {
            $Identifier -eq 'gerber:tools:http:token:github'
        }
        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter {
            $Title -eq '/secrets remove' -and
            $Text -eq "Removed credential 'gerber:tools:http:token:github' from secure credential storage."
        }
    }

    It 'checks whether a credential exists without retrieving its value' {
        Mock Get-GerberMenuSubcommand { @('test', '')[$script:testCredentialCall++] }
        Mock Read-GerberCommand { 'gerber:ado:example:pat' }
        Mock Test-GerberCredential { $true }
        Mock Get-GerberCredential { throw 'The test action must not retrieve the secret.' }
        Mock Show-GerberTextBlock {}
        Mock Wait-GerberContinue {}
        $script:testCredentialCall = 0

        Show-GerberSecretsView -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Test-GerberCredential -Times 1 -ParameterFilter {
            $Identifier -eq 'gerber:ado:example:pat'
        }
        Should -Invoke Get-GerberCredential -Times 0
        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter {
            $Title -eq '/secrets test' -and
            $Text -match 'gerber:ado:example:pat' -and
            $Text -match 'Stored'
        }
    }

    It 'shows the non-clipboard reveal preview when copy fails' {
        $text = Get-GerberSecretRevealPreviewText -ClipboardResult ([pscustomobject]@{
                Success = $false
                Message = 'Clipboard copy is not available in this shell.'
            })

        $text | Should -Be 'Show the plain-text secret value in the terminal.'
    }

    It 'shows the non-clipboard hide preview when copy fails' {
        $text = Get-GerberSecretHidePreviewText -ClipboardResult ([pscustomobject]@{
                Success = $false
                Message = 'Clipboard copy is not available in this shell.'
            })

        $text | Should -Be 'Keep the secret hidden and return to the secrets menu.'
    }

    It 'surfaces the clipboard status message when copy fails' {
        $text = Get-GerberSecretClipboardStatusMessage -ClipboardResult ([pscustomobject]@{
                Success = $false
                Message = 'Clipboard copy is not available in this shell.'
            })

        $text | Should -Be 'Clipboard copy is not available in this shell.'
    }

    It 'converts null, string, and SecureString values into secret text' {
        $secureValue = New-Object System.Security.SecureString
        foreach ($character in 'super-secret-value'.ToCharArray()) {
            $secureValue.AppendChar($character)
        }

        $secureValue.MakeReadOnly()

        (ConvertTo-GerberSecretText -Value $null) | Should -Be ''
        (ConvertTo-GerberSecretText -Value 'text-secret') | Should -Be 'text-secret'
        (ConvertTo-GerberSecretText -Value $secureValue) | Should -Be 'super-secret-value'
    }

    It 'rejects non-text secret values' {
        { ConvertTo-GerberSecretText -Value 42 } | Should -Throw 'Gerber can only reveal secrets stored as text.'
    }

    It 'renders empty secret values with a dedicated placeholder' {
        (Get-GerberSecretDisplayText -Value '') | Should -Be '(empty string)'
    }

    It 'keeps list as the only non-sticky secrets action' {
        $actionTable = Get-GerberSecretsActionTable

        (Test-GerberSecretsStickyAction -Action 'list' -ActionTable $actionTable) | Should -BeFalse
        (Test-GerberSecretsStickyAction -Action 'get' -ActionTable $actionTable) | Should -BeTrue
        (Test-GerberSecretsStickyAction -Action 'oops' -ActionTable $actionTable) | Should -BeFalse
    }
}
