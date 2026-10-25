BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Add-GerberAdoBuildTagIfMissing' {
    It 'adds the normalized tag when the run does not already contain it' {
        Mock Get-GerberAdoBuildTagSet {
            [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        }
        Mock Add-GerberAdoBuildTag {}

        $result = Add-GerberAdoBuildTagIfMissing `
            -Configuration ([pscustomobject]@{}) `
            -Pat 'pat' `
            -BuildId 9001 `
            -Tag ' Juni release 2026 '

        $result | Should -BeTrue
        Should -Invoke Add-GerberAdoBuildTag -Times 1 -ParameterFilter {
            $BuildId -eq 9001 -and
            $Tag -eq 'Juni release 2026'
        }
    }

    It 'skips the tag when the run already contains the normalized value' {
        $tagSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $null = $tagSet.Add('Juni release 2026')
        Mock Get-GerberAdoBuildTagSet { $tagSet }
        Mock Add-GerberAdoBuildTag {}

        $result = Add-GerberAdoBuildTagIfMissing `
            -Configuration ([pscustomobject]@{}) `
            -Pat 'pat' `
            -BuildId 9001 `
            -Tag ' Juni release 2026 '

        $result | Should -BeFalse
        Should -Invoke Add-GerberAdoBuildTag -Times 0
    }

    It 'returns false without querying Azure DevOps when the normalized tag is blank' {
        Mock Get-GerberAdoBuildTagSet {}
        Mock Add-GerberAdoBuildTag {}

        $result = Add-GerberAdoBuildTagIfMissing `
            -Configuration ([pscustomobject]@{}) `
            -Pat 'pat' `
            -BuildId 9001 `
            -Tag '   '

        $result | Should -BeFalse
        Should -Invoke Get-GerberAdoBuildTagSet -Times 0
        Should -Invoke Add-GerberAdoBuildTag -Times 0
    }
}
