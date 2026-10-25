BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Resolve-GerberCredentialIdentifier' {
    It 'normalizes Gerber credential identifiers consistently' {
        Resolve-GerberCredentialIdentifier -Identifier '  Gerber:ADO:EXAMPLE:PAT  ' |
            Should -Be 'gerber:ado:example:pat'
    }

    It 'rejects identifiers outside the Gerber namespace' -ForEach @(
        @{ Identifier = ''; Message = '*must not be empty*' }
        @{ Identifier = 'external:ado:example:pat'; Message = "*must start with 'gerber:'*" }
        @{ Identifier = 'gerber:ado'; Message = '*must contain a scope and credential name*' }
        @{ Identifier = 'gerber:ado:bad value:pat'; Message = '*contain unsupported characters*' }
    ) {
        { Resolve-GerberCredentialIdentifier -Identifier $Identifier } | Should -Throw $Message
    }
}
