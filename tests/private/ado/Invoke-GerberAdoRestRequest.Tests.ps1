BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Invoke-GerberAdoRestRequest' {
    It 'applies timeout configuration from Properties.json to ADO requests' {
        Mock Get-GerberPropertiesData {
            [pscustomobject]@{
                HttpConnectionTimeoutSeconds = 5
                HttpOperationTimeoutSeconds = 15
            }
        }
        Mock Invoke-RestMethod {
            @{ value = @() }
        }

        Invoke-GerberAdoRestRequest `
            -Uri ([uri]'https://ado.example.test/ExampleProject/_apis/distributedtask/pools') `
            -Pat 'pat' `
            -RequestLabel 'automation pools' `
            -CredentialIdentifier 'gerber:ado:example:pat'

        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
            $ConnectionTimeoutSeconds -eq 5 -and
            $OperationTimeoutSeconds -eq 15
        }
    }

    It 'retries transient ADO request failures before succeeding' {
        Mock Get-GerberPropertiesData {
            [pscustomobject]@{
                HttpConnectionTimeoutSeconds = 5
                HttpOperationTimeoutSeconds = 15
            }
        }
        $script:attemptCount = 0
        Mock Start-Sleep {}
        Mock Invoke-RestMethod {
            $script:attemptCount++
            if ($script:attemptCount -lt 3) {
                throw [System.Threading.Tasks.TaskCanceledException]::new('Timed out')
            }

            return @{ value = @() }
        }

        $null = Invoke-GerberAdoRestRequest `
            -Uri ([uri]'https://ado.example.test/ExampleProject/_apis/distributedtask/pools') `
            -Pat 'pat' `
            -RequestLabel 'automation pools' `
            -CredentialIdentifier 'gerber:ado:example:pat'

        Should -Invoke Invoke-RestMethod -Times 3
        Should -Invoke Start-Sleep -Times 2 -ParameterFilter { $Seconds -in @(1, 2) }
    }

    It 'wraps timeout and generic request failures in Gerber-owned argument errors' {
        Mock Get-GerberPropertiesData {
            [pscustomobject]@{
                HttpConnectionTimeoutSeconds = 5
                HttpOperationTimeoutSeconds = 15
            }
        }
        Mock Invoke-RestMethod { throw [System.Threading.Tasks.TaskCanceledException]::new('Timed out') }

        { Invoke-GerberAdoRestRequest -Uri ([uri]'https://ado.example.test/test') -Pat 'pat' -RequestLabel 'automation pools' -CredentialIdentifier 'gerber:ado:example:pat' } |
            Should -Throw "*Try again in a moment*"

        Mock Invoke-RestMethod { throw [System.Exception]::new('Bad request') }

        { Invoke-GerberAdoRestRequest -Uri ([uri]'https://ado.example.test/test') -Pat 'pat' -RequestLabel 'automation pools' -CredentialIdentifier 'gerber:ado:example:pat' } |
            Should -Throw "*Gerber could not read Azure DevOps automation pools from 'https://ado.example.test/test'. Bad request*"
    }
}
