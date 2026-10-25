BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberAdoHttpStatusCode' {
    It 'returns 0 when exception has no response property' {
        $exceptionWithoutResponse = [System.Exception]::new('Generic error')

        $statusCode = Get-GerberAdoHttpStatusCode -Exception $exceptionWithoutResponse

        $statusCode | Should -Be 0
    }

    It 'returns 0 when exception response has no StatusCode property' {
        $exceptionWithResponse = [System.Exception]::new('Error')
        $exceptionWithResponse | Add-Member -MemberType NoteProperty -Name Response -Value ([pscustomobject]@{ SomeOtherProperty = 'value' })

        $statusCode = Get-GerberAdoHttpStatusCode -Exception $exceptionWithResponse

        $statusCode | Should -Be 0
    }

    It 'returns 0 when the exception Response property exists but is null' {
        $exception = [System.Exception]::new('Request failed')
        $exception | Add-Member -MemberType NoteProperty -Name Response -Value $null

        (Get-GerberAdoHttpStatusCode -Exception $exception) | Should -Be 0
    }
}
