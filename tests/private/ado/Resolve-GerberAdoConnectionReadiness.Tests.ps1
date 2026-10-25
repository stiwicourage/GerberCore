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
}
