BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Resolve-GerberAdoPat' {
    It 'retrieves the PAT through the shared readiness flow when the profile name is available' {
        Mock Resolve-GerberAdoConnectionReadiness {
            [pscustomobject]@{
                Pat = 'stored-pat'
            }
        }

        $result = Resolve-GerberAdoPat -Configuration ([pscustomobject]@{
                ProfileName = 'example'
                CredentialIdentifier = 'gerber:ado:example:pat'
            })

        $result | Should -Be 'stored-pat'
        Should -Invoke Resolve-GerberAdoConnectionReadiness -Times 1 -ParameterFilter {
            $ProfileName -eq 'example' -and
            $RequireAuthentication -and
            $CommandLabel -eq 'the requested Azure DevOps operation'
        }
    }

    It 'falls back to the direct credential lookup when no profile name is available' {
        Mock Get-GerberCredential { 'stored-pat' }

        $result = Resolve-GerberAdoPat -Configuration ([pscustomobject]@{
                CredentialIdentifier = 'gerber:ado:example:pat'
            })

        $result | Should -Be 'stored-pat'
        Should -Invoke Get-GerberCredential -Times 1 -ParameterFilter {
            $Identifier -eq 'gerber:ado:example:pat'
        }
    }

    It 'fails actionably when the direct credential lookup is missing' {
        Mock Get-GerberCredential { $null }

        {
            Resolve-GerberAdoPat -Configuration ([pscustomobject]@{
                    CredentialIdentifier = 'gerber:ado:example:pat'
                })
        } | Should -Throw "*credential 'gerber:ado:example:pat'*with /secrets set*"
    }

    It 'treats an empty stored value as a missing PAT during direct lookup' {
        Mock Get-GerberCredential { '   ' }

        {
            Resolve-GerberAdoPat -Configuration ([pscustomobject]@{
                    CredentialIdentifier = 'gerber:ado:example:pat'
                })
        } | Should -Throw "*credential 'gerber:ado:example:pat'*with /secrets set*"
    }

    It 'does not read environment variables or prompt for credentials' {
        Mock Get-Item { throw 'Environment access is not allowed for ADO PAT resolution.' }
        Mock Read-GerberSecureValue { throw 'Interactive ADO onboarding belongs to G-2E.' }
        Mock Resolve-GerberAdoConnectionReadiness {
            [pscustomobject]@{
                Pat = 'stored-pat'
            }
        }

        Resolve-GerberAdoPat -Configuration ([pscustomobject]@{
                ProfileName = 'example'
                CredentialIdentifier = 'gerber:ado:example:pat'
            }) | Should -Be 'stored-pat'

        Should -Invoke Get-Item -Times 0
        Should -Invoke Read-GerberSecureValue -Times 0
    }

    It 'keeps profile credentials isolated' {
        Mock Resolve-GerberAdoConnectionReadiness {
            if ($ProfileName -eq 'example') {
                return [pscustomobject]@{ Pat = 'example-pat' }
            }

            return [pscustomobject]@{ Pat = 'other-pat' }
        }

        $example = Resolve-GerberAdoPat -Configuration ([pscustomobject]@{
                ProfileName = 'example'
                CredentialIdentifier = 'gerber:ado:example:pat'
            })
        $other = Resolve-GerberAdoPat -Configuration ([pscustomobject]@{
                ProfileName = 'other'
                CredentialIdentifier = 'gerber:ado:other:pat'
            })

        $example | Should -Be 'example-pat'
        $other | Should -Be 'other-pat'
    }
}
