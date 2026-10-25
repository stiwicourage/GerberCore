BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot

    function ConvertTo-TestGerberSecureValue {
        param(
            [Parameter(Mandatory)]
            [string]$Text
        )

        $secureValue = [System.Security.SecureString]::new()
        foreach ($character in $Text.ToCharArray()) {
            $secureValue.AppendChar($character)
        }

        $secureValue.MakeReadOnly()
        return $secureValue
    }
}

Describe 'Resolve-GerberAdoConnectionReadiness' {
    BeforeEach {
        $script:userConfiguration = @{
            schemaVersion = 1
        }
        $script:credentialTable = @{}
        $script:savedConfiguration = $null

        Mock Resolve-GerberUserConfigPath { '/tmp/gerber/config.json' }
        Mock Test-GerberConsoleInputRedirected { $false }
        Mock Get-GerberUserConfiguration { $script:userConfiguration }
        Mock Save-GerberUserConfiguration {
            $script:savedConfiguration = $Configuration
            $script:userConfiguration = $Configuration
        }
        Mock Read-GerberCommand {}
        Mock Read-GerberSecureValue {}
        Mock Get-GerberCredential {
            if ($script:credentialTable.ContainsKey($Identifier)) {
                return $script:credentialTable[$Identifier]
            }

            return $null
        }
        Mock Test-GerberCredential { $script:credentialTable.ContainsKey($Identifier) }
        Mock Set-GerberCredential { $script:credentialTable[$Identifier] = $Secret }
        Mock Show-GerberTextBlock {}
        Mock Wait-GerberContinue {}
        Remove-Variable -Name GerberAdoSessionProfileName -Scope Script -ErrorAction SilentlyContinue
    }

    It 'returns the default profile without prompting when configuration already exists' {
        $script:userConfiguration = @{
            schemaVersion = 1
            ado = @{
                defaultProfile = 'example'
                profiles = [ordered]@{
                    example = @{
                        projectUrl = 'https://dev.azure.com/example-org/SampleProject'
                    }
                }
            }
        }

        $result = Resolve-GerberAdoConnectionReadiness

        $result.ConnectionProfile.ProfileName | Should -Be 'example'
        $result.CredentialIdentifier | Should -Be 'gerber:ado:example:pat'
        Should -Invoke Read-GerberCommand -Times 0
        Should -Invoke Read-GerberSecureValue -Times 0
    }

    It 'configures a new profile and PAT when no connection exists' {
        $script:commandResponses = @(
            ''
            'https://dev.azure.com/example-org/SampleProject'
            'example'
            ''
        )
        $script:commandIndex = 0
        Mock Read-GerberCommand {
            $response = $script:commandResponses[$script:commandIndex]
            $script:commandIndex++
            return $response
        }
        Mock Read-GerberSecureValue { ConvertTo-TestGerberSecureValue -Text 'new-pat' }

        $result = Resolve-GerberAdoConnectionReadiness -RequireAuthentication -CommandLabel '/repository review'

        $result.ConnectionProfile.ProfileName | Should -Be 'example'
        $result.ConnectionProfile.ProjectUri.AbsoluteUri | Should -Be 'https://dev.azure.com/example-org/SampleProject'
        $result.Pat | Should -Be 'new-pat'
        $script:userConfiguration.ado.defaultProfile | Should -Be 'example'
        $script:userConfiguration.ado.profiles.example.projectUrl | Should -Be 'https://dev.azure.com/example-org/SampleProject'
        $script:credentialTable['gerber:ado:example:pat'] | Should -Be 'new-pat'
    }

    It 'cancels cleanly when the user declines first-use setup' {
        Mock Read-GerberCommand { 'n' }
        Mock Read-GerberSecureValue { throw 'Should not be called.' }

        { Resolve-GerberAdoConnectionReadiness -RequireAuthentication -CommandLabel '/repository review' } |
            Should -Throw 'Go back to the previous Gerber menu.'

        $script:userConfiguration.Keys | Should -Be @('schemaVersion')
        Should -Invoke Read-GerberSecureValue -Times 0
    }

    It 're-prompts after an invalid project URL without restarting the operation' {
        $script:commandResponses = @(
            ''
            'not-a-url'
            'https://dev.azure.com/example-org/SampleProject'
            'example'
            'n'
        )
        $script:commandIndex = 0
        Mock Read-GerberCommand {
            $response = $script:commandResponses[$script:commandIndex]
            $script:commandIndex++
            return $response
        }

        $result = Resolve-GerberAdoConnectionReadiness -CommandLabel '/list ado-agents'

        $result.ConnectionProfile.ProfileName | Should -Be 'example'
        $script:userConfiguration.ado.profiles.example.projectUrl | Should -Be 'https://dev.azure.com/example-org/SampleProject'
        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter {
            $Title -eq '/list ado-agents' -and
            $Text -like '*Provide a full Azure DevOps project URL*'
        }
    }

    It 'fails clearly without prompting when an explicit profile is missing in non-interactive execution' {
        Mock Test-GerberConsoleInputRedirected { $true }
        Mock Read-GerberCommand {}

        {
            Resolve-GerberAdoConnectionReadiness -ProfileName 'example' -RequireAuthentication -CommandLabel '/repository review'
        } | Should -Throw "*profile 'example' is not configured*secure credential storage first*rerun Gerber interactively*"

        Should -Invoke Read-GerberCommand -Times 0
    }

    It 'uses the only available profile when no default exists and does not write configuration when default is declined' {
        $script:userConfiguration = @{
            schemaVersion = 1
            ado = @{
                profiles = [ordered]@{
                    example = @{
                        projectUrl = 'https://dev.azure.com/example-org/SampleProject'
                    }
                }
            }
        }
        $script:commandResponses = @('', 'n')
        $script:commandIndex = 0
        Mock Read-GerberCommand {
            $response = $script:commandResponses[$script:commandIndex]
            $script:commandIndex++
            return $response
        }

        $result = Resolve-GerberAdoConnectionReadiness -CommandLabel '/list ado-agents'

        $result.ConnectionProfile.ProfileName | Should -Be 'example'
        $script:savedConfiguration | Should -BeNullOrEmpty
        $script:userConfiguration.ado.ContainsKey('defaultProfile') | Should -BeFalse
    }

    It 'lets the user select one profile when multiple profiles exist without a default' {
        $script:userConfiguration = @{
            schemaVersion = 1
            ado = @{
                profiles = [ordered]@{
                    example = @{
                        projectUrl = 'https://dev.azure.com/example-org/SampleProject'
                    }
                    atlas = @{
                        projectUrl = 'https://dev.azure.com/example-org/Atlas'
                    }
                }
            }
        }
        $script:commandResponses = @('ATLAS', '')
        $script:commandIndex = 0
        Mock Read-GerberCommand {
            $response = $script:commandResponses[$script:commandIndex]
            $script:commandIndex++
            return $response
        }

        $result = Resolve-GerberAdoConnectionReadiness -CommandLabel '/list ado-team-members'

        $result.ConnectionProfile.ProfileName | Should -Be 'atlas'
        $script:userConfiguration.ado.defaultProfile | Should -Be 'atlas'
    }

    It 'prompts only for a missing PAT when the connection metadata already exists' {
        $script:userConfiguration = @{
            schemaVersion = 1
            ado = @{
                defaultProfile = 'example'
                profiles = [ordered]@{
                    example = @{
                        projectUrl = 'https://dev.azure.com/example-org/SampleProject'
                    }
                }
            }
        }
        Mock Read-GerberCommand { '' }
        Mock Read-GerberSecureValue { ConvertTo-TestGerberSecureValue -Text 'new-pat' }

        $result = Resolve-GerberAdoConnectionReadiness -RequireAuthentication -CommandLabel '/repository review'

        $result.ConnectionProfile.ProfileName | Should -Be 'example'
        $result.Pat | Should -Be 'new-pat'
        $script:savedConfiguration | Should -BeNullOrEmpty
        $script:credentialTable['gerber:ado:example:pat'] | Should -Be 'new-pat'
    }

    It 'requires confirmation before overwriting an existing PAT during explicit PAT setup' {
        $script:credentialTable['gerber:ado:example:pat'] = 'old-pat'
        $script:commandResponses = @('')
        $script:commandIndex = 0
        Mock Read-GerberCommand {
            $response = $script:commandResponses[$script:commandIndex]
            $script:commandIndex++
            return $response
        }
        Mock Read-GerberSecureValue { ConvertTo-TestGerberSecureValue -Text 'new-pat' }

        $result = Save-GerberAdoConnectionPat -CommandLabel '/repository review' -ProfileName 'example'

        $result | Should -Be 'new-pat'
        Should -Invoke Read-GerberCommand -Times 1
        $script:credentialTable['gerber:ado:example:pat'] | Should -Be 'new-pat'
    }

    It 'reports partial failure clearly when credential storage fails after metadata is saved' {
        $script:commandResponses = @(
            ''
            'https://dev.azure.com/example-org/SampleProject'
            'example'
            ''
        )
        $script:commandIndex = 0
        Mock Read-GerberCommand {
            $response = $script:commandResponses[$script:commandIndex]
            $script:commandIndex++
            return $response
        }
        Mock Read-GerberSecureValue { ConvertTo-TestGerberSecureValue -Text 'new-pat' }
        Mock Set-GerberCredential { throw [System.InvalidOperationException]::new('Credential store unavailable.') }

        {
            Resolve-GerberAdoConnectionReadiness -RequireAuthentication -CommandLabel '/repository review'
        } | Should -Throw "*saved Azure DevOps connection 'example'*Credential store unavailable*"

        $script:userConfiguration.ado.defaultProfile | Should -Be 'example'
        $script:userConfiguration.ado.profiles.example.projectUrl | Should -Be 'https://dev.azure.com/example-org/SampleProject'
    }

    Context 'scripted prompts' {
        BeforeEach {
            $script:commandResponses = @()
            $script:commandIndex = 0
            Mock Read-GerberCommand {
                $response = ''
                if ($script:commandIndex -lt $script:commandResponses.Count) {
                    $response = $script:commandResponses[$script:commandIndex]
                }
                $script:commandIndex++
                return $response
            }
            Mock Read-GerberSecureValue { ConvertTo-TestGerberSecureValue -Text 'new-pat' }
        }

        It 'creates a missing explicit profile after confirmation' {
            $script:commandResponses = @('y', 'https://dev.azure.com/example-org/SampleProject', 'n')

            $result = Resolve-GerberAdoConnectionReadiness -ProfileName 'fresh'

            $result.ConnectionProfile.ProfileName | Should -Be 'fresh'
            $script:userConfiguration.ado.profiles.fresh.projectUrl | Should -Be 'https://dev.azure.com/example-org/SampleProject'
        }

        It 'throws when the user declines <Scenario>' -ForEach @(
            @{ Scenario = 'configuring a missing explicit profile'; Responses = @('no'); Arguments = @{ ProfileName = 'fresh' } }
            @{ Scenario = 'the only existing profile'; Responses = @('n'); Arguments = @{ Setup = 'single' } }
        ) {
            if ($Arguments.Setup -eq 'single') {
                $script:userConfiguration = @{
                    schemaVersion = 1
                    ado = @{ profiles = [ordered]@{ example = @{ projectUrl = 'https://dev.azure.com/example-org/SampleProject' } } }
                }
                $Arguments = @{}
            }
            $script:commandResponses = $Responses

            { Resolve-GerberAdoConnectionReadiness @Arguments } | Should -Throw
        }

        It 'asks for the server root when the project URL does not reveal it and retries invalid roots' {
            $script:commandResponses = @(
                'y'
                'https://ado.example.com/root/Collection/Project'
                'https://other.example.com/root'
                'https://ado.example.com/root'
                'server'
                'n'
            )

            $result = Resolve-GerberAdoConnectionReadiness

            $result.ConnectionProfile.ProfileName | Should -Be 'server'
            $script:userConfiguration.ado.profiles.server.deploymentType | Should -Be 'Server'
            $script:userConfiguration.ado.profiles.server.serverUrl | Should -Be 'https://ado.example.com/root'
        }

        It 'rejects duplicate connection names until a unique one is entered' {
            $script:commandResponses = @('example', 'other')
            $existing = @([pscustomobject]@{ Name = 'Example' })

            $name = Read-GerberAdoNewConnectionProfileName -CommandLabel 'x' -ExistingProfileList $existing -ProjectUri ([uri]'https://dev.azure.com/o/p')

            $name | Should -Be 'other'
            Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter { $Text -like '*already exists*Project URL: https://dev.azure.com/o/p*' }
        }

        It 'selects an existing profile by name after rejecting unknown names' {
            $list = @([pscustomobject]@{ Name = 'one'; ProjectUrl = 'u1' }, [pscustomobject]@{ Name = 'two'; ProjectUrl = 'u2' })
            $script:commandResponses = @('missing', 'TWO')

            (Read-GerberAdoExistingConnectionProfile -CommandLabel 'x' -ProfileList $list).Name | Should -Be 'two'

            Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter { $Text -like "*could not find Azure DevOps profile 'missing'*" }
        }

        It 'lists profiles for selection' {
            $list = @([pscustomobject]@{ Name = 'one'; ProjectUrl = 'u1' })

            Get-GerberAdoSetupSelectionText -ProfileList $list | Should -BeLike '*- one: u1*'
        }

        It 'interprets confirmation answers' -ForEach @(
            @{ Answers = @('yes'); Expected = $true }
            @{ Answers = @('NO'); Expected = $false }
            @{ Answers = @('maybe', 'y'); Expected = $true }
        ) {
            $script:commandResponses = $Answers

            Read-GerberAdoSetupConfirmation -CommandLabel 'x' -ScreenText 'text' -Prompt 'Q' | Should -Be $Expected
        }

        It 'writes server details into the profile map' {
            $resolution = [pscustomobject]@{
                ProjectUri = [uri]'https://tfs.example.com/tfs/C/P/'
                DeploymentType = 'Server'
                ServerUri = [uri]'https://tfs.example.com/tfs/'
            }

            $map = Get-GerberAdoConnectionProfileConfigMap -ProjectResolution $resolution

            $map.projectUrl | Should -Be 'https://tfs.example.com/tfs/C/P'
            $map.serverUrl | Should -Be 'https://tfs.example.com/tfs'
        }

        It 'throws when the PAT overwrite or PAT setup is declined' {
            $script:credentialTable['gerber:ado:example:pat'] = 'old'
            $script:commandResponses = @('n')
            { Confirm-GerberAdoConnectionPatOverwrite -CommandLabel 'x' -ProfileName 'example' -Identifier 'gerber:ado:example:pat' } | Should -Throw

            $script:credentialTable.Clear()
            $script:commandIndex = 0
            $connectionProfile = [pscustomobject]@{ ProfileName = 'example'; ProjectUri = [uri]'https://dev.azure.com/o/p' }
            { Resolve-GerberAdoConnectionPat -ConnectionProfile $connectionProfile -PatIdentifier 'gerber:ado:example:pat' -CommandLabel 'x' } | Should -Throw
        }

        It 'rejects an empty PAT' {
            Mock Read-GerberSecureValue { ConvertTo-TestGerberSecureValue -Text ' ' }

            { Read-GerberAdoConnectionPatValue -Identifier 'gerber:ado:example:pat' } | Should -Throw '*Enter a Personal Access Token*'
        }

        It 'forgets a session profile that no longer exists' {
            $script:GerberAdoSessionProfileName = 'ghost'

            Get-GerberSessionAdoProfile -Configuration $script:userConfiguration | Should -BeNullOrEmpty
            $script:GerberAdoSessionProfileName | Should -BeNullOrEmpty
        }

        It 'reuses an existing explicit profile or the session profile without prompting' {
            $script:userConfiguration = @{
                schemaVersion = 1
                ado = @{
                    profiles = [ordered]@{
                        one = @{ projectUrl = 'https://dev.azure.com/example-org/One' }
                        two = @{ projectUrl = 'https://dev.azure.com/example-org/Two' }
                    }
                }
            }

            (Resolve-GerberAdoConnectionReadiness -ProfileName 'two').ConnectionProfile.ProfileName | Should -Be 'two'
            (Resolve-GerberAdoConnectionReadiness).ConnectionProfile.ProfileName | Should -Be 'two'
            Should -Invoke Read-GerberCommand -Times 0
        }

        It 're-prompts for the PAT after an empty value' {
            $script:secureValues = @(' ', 'good-pat')
            $script:secureIndex = 0
            Mock Read-GerberSecureValue {
                $value = $script:secureValues[$script:secureIndex]
                $script:secureIndex++
                ConvertTo-TestGerberSecureValue -Text $value
            }

            Save-GerberAdoConnectionPat -CommandLabel 'x' -ProfileName 'example' | Should -Be 'good-pat'
            Should -Invoke Show-GerberTextBlock -Times 1
        }
    }
}
