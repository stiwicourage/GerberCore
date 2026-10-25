BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Test-GerberAdoRetriableFailure' {
    It 'treats transient server failures as retriable' {
        $exception = [System.Exception]::new('Bad gateway')
        $exception | Add-Member -MemberType NoteProperty -Name Response -Value ([pscustomobject]@{ StatusCode = 502 })

        (Test-GerberAdoRetriableFailure -Exception $exception) | Should -BeTrue
    }

    It 'does not retry unauthorized failures' {
        $exception = [System.Exception]::new('Unauthorized')
        $exception | Add-Member -MemberType NoteProperty -Name Response -Value ([pscustomobject]@{ StatusCode = 401 })

        (Test-GerberAdoRetriableFailure -Exception $exception) | Should -BeFalse
    }
}
