BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Test-GerberAdoUnauthorizedFailure' {
    It 'detects unauthorized and forbidden responses' {
        $forbidden = [System.Exception]::new('Unauthorized')
        $forbidden | Add-Member -MemberType NoteProperty -Name Response -Value ([pscustomobject]@{ StatusCode = 403 })
        $unauthorized = [System.Exception]::new('Unauthorized')
        $unauthorized | Add-Member -MemberType NoteProperty -Name Response -Value ([pscustomobject]@{ StatusCode = 401 })

        (Test-GerberAdoUnauthorizedFailure -Exception $forbidden) | Should -BeTrue
        (Test-GerberAdoUnauthorizedFailure -Exception $unauthorized) | Should -BeTrue
    }

    It 'returns false for other failures' {
        $exception = [System.Exception]::new('Bad gateway')
        $exception | Add-Member -MemberType NoteProperty -Name Response -Value ([pscustomobject]@{ StatusCode = 502 })

        (Test-GerberAdoUnauthorizedFailure -Exception $exception) | Should -BeFalse
    }
}
