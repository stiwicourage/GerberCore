BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Invoke-GerberAdoRestMutation' {
    It 'calls Invoke-RestMethod with method uri body and headers from context' {
        $httpConfig = [pscustomobject]@{ ConnectionTimeoutSeconds = 30; OperationTimeoutSeconds = 60 }
        $headers = @{ Authorization = 'Basic abc' }
        $mutationContext = [pscustomobject]@{
            Pat                    = 'test-pat'
            Method                 = 'POST'
            Uri                    = [uri]'https://ado.example.com/org/policy'
            Body                   = '{"type":"test"}'
            RequestLabel           = 'create policy'
            CredentialIdentifier = 'MY_PAT'
        }
        Mock Get-GerberHttpConfiguration { $httpConfig }
        Mock Get-GerberAdoRequestHeader { $headers }
        Mock Invoke-RestMethod {}

        Invoke-GerberAdoRestMutation -MutationContext $mutationContext

        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
            $Method -eq 'POST' -and $Uri -eq $mutationContext.Uri -and $Body -eq $mutationContext.Body
        }
    }

    It 'throws a wrapped ArgumentException when Invoke-RestMethod fails' {
        $httpConfig = [pscustomobject]@{ ConnectionTimeoutSeconds = 30; OperationTimeoutSeconds = 60 }
        $mutationContext = [pscustomobject]@{
            Pat                    = 'test-pat'
            Method                 = 'PUT'
            Uri                    = [uri]'https://ado.example.com/org/policy/5'
            Body                   = '{}'
            RequestLabel           = 'update policy'
            CredentialIdentifier = 'MY_PAT'
        }
        Mock Get-GerberHttpConfiguration { $httpConfig }
        Mock Get-GerberAdoRequestHeader { @{} }
        Mock Invoke-RestMethod { throw [System.Net.WebException]::new('connection failed') }
        Mock Get-GerberAdoRequestFailureMessage { 'policy update failed: connection failed' }

        { Invoke-GerberAdoRestMutation -MutationContext $mutationContext } | Should -Throw -ExceptionType ([System.ArgumentException])
    }
}

Describe 'Get-GerberAdoMutationFailure' {
    It 'returns an ArgumentException wrapping the original exception' {
        $mutationContext = [pscustomobject]@{
            Uri                    = [uri]'https://ado.example.com/org/policy'
            RequestLabel           = 'create policy'
            CredentialIdentifier = 'MY_PAT'
        }
        $inner = [System.InvalidOperationException]::new('inner error')
        Mock Get-GerberAdoRequestFailureMessage { 'friendly failure message' }

        $result = Get-GerberAdoMutationFailure -MutationContext $mutationContext -Exception $inner

        $result | Should -BeOfType ([System.ArgumentException])
        $result.Message | Should -Be 'friendly failure message'
        $result.InnerException | Should -Be $inner
    }

    It 'passes uri requestlabel and envvar name to Get-GerberAdoRequestFailureMessage' {
        $mutationContext = [pscustomobject]@{
            Uri                    = [uri]'https://ado.example.com/org/policy/99'
            RequestLabel           = 'update policy'
            CredentialIdentifier = 'ADO_PAT'
        }
        Mock Get-GerberAdoRequestFailureMessage { 'fail' } -ParameterFilter {
            $RequestLabel -eq 'update policy' -and $PatAccountIdentifier -eq 'ADO_PAT'
        }

        Get-GerberAdoMutationFailure -MutationContext $mutationContext -Exception $null

        Should -Invoke Get-GerberAdoRequestFailureMessage -Times 1
    }
}
