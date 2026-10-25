BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    . "$root/src/private/update/Invoke-GerberStartupUpdateCheck.ps1"
    . "$root/src/private/update/Resolve-GerberCoreUpdateRequest.ps1"
    . "$root/src/private/update/Invoke-GerberUpdateProbe.ps1"
    . "$root/src/private/credentials/Get-GerberCredential.ps1"
    Import-Module PSModuleUpdate
}

Describe 'Invoke-GerberStartupUpdateCheck' -Tag 'G4A7' {
    BeforeEach {
        $script:request = [pscustomobject]@{ Module = [pscustomobject]@{ ModuleBase = '/isolated/Gerber' }; Repository = 'Feed'; Policy = @{}; CredentialSetting = $null }
        Mock Resolve-GerberCoreUpdateRequest { $script:request }
        Mock Invoke-GerberUpdateProbe { [pscustomobject]@{ Status = 'Available'; Available = '0.2.0'; Message = 'Update available' } }
        Mock Get-GerberCredential { throw 'Native storage must not initialize at startup' }
        Mock Install-PSModuleUpdate { throw 'Startup must never install' }
    }

    Context 'prompt-free bounded startup' {
        It 'returns presentation-only availability using the two-second probe budget' {
            $result = Invoke-GerberStartupUpdateCheck
            $result.Status | Should -Be 'Available'
            Should -Invoke Invoke-GerberUpdateProbe -Times 1 -ParameterFilter { $TimeoutMilliseconds -eq 2000 }
            Should -Invoke Install-PSModuleUpdate -Times 0
            Should -Invoke Get-GerberCredential -Times 0
        }

        It 'ignores obsolete secret-bound request fields and still probes without credentials' {
            $script:request.CredentialSetting = @{ identifier = 'secret'; username = 'user' }
            (Invoke-GerberStartupUpdateCheck).Status | Should -Be 'Available'
            Should -Invoke Invoke-GerberUpdateProbe -Times 1
            Should -Invoke Get-GerberCredential -Times 0
        }

        It 'allows normal startup after offline, timeout or no-update summaries' -ForEach @('Unavailable', 'TimedOut', 'UpToDate', 'NoMatchingPackage') {
            $status = $_
            Mock Invoke-GerberUpdateProbe { [pscustomobject]@{ Status = $status } }
            (Invoke-GerberStartupUpdateCheck).Status | Should -Be $status
            Should -Invoke Install-PSModuleUpdate -Times 0
        }

        It 'contains malformed config errors without exposing their raw content' {
            Mock Resolve-GerberCoreUpdateRequest { throw 'credential-bearing configuration' }
            $result = Invoke-GerberStartupUpdateCheck
            $result.Status | Should -Be 'Unavailable'
            ($result | ConvertTo-Json) | Should -Not -Match 'credential-bearing'
        }
    }
}
