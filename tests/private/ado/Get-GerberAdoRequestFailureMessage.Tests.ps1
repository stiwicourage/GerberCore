BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoRequestFailureMessage' {
    It 'shows a Gerber-owned invalid-token message for HTTP 401 responses' {
        $exception = [System.Exception]::new('Unauthorized')
        $exception | Add-Member -MemberType NoteProperty -Name Response -Value ([pscustomobject]@{ StatusCode = 401 })

        $result = Get-GerberAdoRequestFailureMessage `
            -Uri ([uri]'https://ado.example.test/ExampleProject/_apis/distributedtask/pools') `
            -RequestLabel 'automation pools' `
            -CredentialIdentifier 'gerber:ado:example:pat' `
            -Exception $exception

        $result | Should -Match "PAT credential 'gerber:ado:example:pat' was rejected"
    }

    It 'shows a Gerber-owned permission message for HTTP 403 responses' {
        $exception = [System.Exception]::new('Forbidden')
        $exception | Add-Member -MemberType NoteProperty -Name Response -Value ([pscustomobject]@{ StatusCode = 403 })

        $result = Get-GerberAdoRequestFailureMessage `
            -Uri ([uri]'https://ado.example.test/ExampleProject/_apis/distributedtask/pools') `
            -RequestLabel 'automation pools' `
            -CredentialIdentifier 'gerber:ado:example:pat' `
            -Exception $exception

        $result | Should -Match "does not have the required permissions"
    }

    It 'provides generic fallback message when exception is null or empty' {
        $message1 = Get-GerberAdoRequestFailureMessage `
            -Uri 'https://ado.example.com' `
            -RequestLabel 'pools' `
            -CredentialIdentifier 'gerber:ado:example:pat' `
            -Exception $null

        $message2 = Get-GerberAdoRequestFailureMessage `
            -Uri 'https://ado.example.com' `
            -RequestLabel 'pools' `
            -CredentialIdentifier 'gerber:ado:example:pat' `
            -Exception ([System.Exception]::new(''))

        $message1 | Should -BeLike '*Try again in a moment.*'
        $message2 | Should -BeLike '*Try again in a moment.*'
    }
}
