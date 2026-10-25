BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    . "$root/src/private/update/Resolve-GerberCoreUpdateRequest.ps1"
    . "$root/src/private/config/Get-GerberUserConfiguration.ps1"
}

Describe 'Resolve-GerberCoreUpdateRequest' -Tag 'G4A7' {
    BeforeEach {
        Mock Get-GerberUserConfiguration { throw 'Core must not read user or plugin configuration' }
        Mock Get-Command { [pscustomobject]@{ Module = [pscustomobject]@{ Name = 'Gerber'; ModuleBase = '/isolated/Gerber' } } }
    }

    Context 'application-owned official source' {
        It 'selects the executing module without reading obsolete or absent configuration' {
            $request = Resolve-GerberCoreUpdateRequest
            $request.Module.Name | Should -BeExactly 'Gerber'
            Should -Invoke Get-GerberUserConfiguration -Times 0
            $request.PSObject.Properties.Name | Should -Not -Contain 'CredentialSetting'
            $request.PSObject.Properties.Name | Should -Not -Contain 'Repository'
            $request.PSObject.Properties.Name | Should -Not -Contain 'Policy'
        }

        It 'requires the executing module rather than guessing an installed copy' {
            Mock Get-Command { [pscustomobject]@{ Module = $null } }
            { Resolve-GerberCoreUpdateRequest } | Should -Throw '*executing Gerber*'
        }
    }
}
