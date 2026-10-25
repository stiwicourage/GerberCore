BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot

    function Use-GerberUserConfigurationPathMock {
        param(
            [Parameter(Mandatory)]
            [string]$ConfigPath
        )

        $script:GerberUserConfigurationPath = $ConfigPath
        Mock Resolve-GerberUserConfigPath { $script:GerberUserConfigurationPath }
    }

    function Get-GerberUserConfigurationTestFile {
        param(
            [Parameter(Mandatory)]
            [string]$RelativePath,

            [Parameter(Mandatory)]
            [AllowEmptyString()]
            [string]$Content
        )

        $configPath = Join-Path $TestDrive $RelativePath
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $configPath) -Force
        Set-Content -LiteralPath $configPath -Value $Content
        Use-GerberUserConfigurationPathMock -ConfigPath $configPath
        return $configPath
    }
}

Describe 'Get-GerberUserConfiguration' {
    It 'returns the default configuration when the file is missing' {
        $configPath = Join-Path $TestDrive 'missing/config.json'
        Use-GerberUserConfigurationPathMock -ConfigPath $configPath

        $result = Get-GerberUserConfiguration

        $result | Should -BeOfType [hashtable]
        $result.schemaVersion | Should -Be 1
    }

    It 'does not create a file, prompt for credentials, or initialize credential storage when the file is missing' {
        $configPath = Join-Path $TestDrive 'missing/config.json'
        Use-GerberUserConfigurationPathMock -ConfigPath $configPath
        Mock Get-Credential { throw 'Get-Credential should not be called.' }
        Remove-Variable -Name GerberCredentialStore -Scope Script -ErrorAction SilentlyContinue

        $null = Get-GerberUserConfiguration

        (Test-Path -LiteralPath $configPath) | Should -BeFalse
        Should -Invoke Get-Credential -Times 0
        Get-Variable -Name GerberCredentialStore -Scope Script -ErrorAction SilentlyContinue |
            Should -BeNullOrEmpty
    }

    It 'loads a valid minimal configuration file' {
        $null = Get-GerberUserConfigurationTestFile `
            -RelativePath 'user/config.json' `
            -Content '{ "schemaVersion": 1 }'

        $result = Get-GerberUserConfiguration

        $result.schemaVersion | Should -Be 1
    }

    It 'preserves unknown properties when loading an existing configuration file' {
        $null = Get-GerberUserConfigurationTestFile -RelativePath 'user/config.json' -Content @'
{
  "schemaVersion": 1,
  "preferences": {
    "theme": "dark"
  },
  "list": [
    "one",
    "two"
  ]
}
'@

        $result = Get-GerberUserConfiguration

        $result.preferences.theme | Should -Be 'dark'
        @($result.list) | Should -Be @('one', 'two')
    }

    It 'rejects invalid configuration content' -ForEach @(
        @{ Content = '{'; ErrorMessage = '*could not parse*' }
        @{ Content = ''; ErrorMessage = '*is empty*' }
        @{ Content = '[1,2,3]'; ErrorMessage = '*must be a JSON object*' }
        @{ Content = 'true'; ErrorMessage = '*must be a JSON object*' }
        @{ Content = '{ "preferences": { "theme": "dark" } }'; ErrorMessage = '*schemaVersion*' }
        @{ Content = '{ "schemaVersion": 999 }'; ErrorMessage = "*Unsupported schemaVersion '999'*" }
    ) {
        param($Content, $ErrorMessage)

        $null = Get-GerberUserConfigurationTestFile -RelativePath 'user/config.json' -Content $Content
        { Get-GerberUserConfiguration } | Should -Throw $ErrorMessage
    }

    It 'includes the configuration path in unreadable-file errors' {
        $configPath = Join-Path $TestDrive 'user/config.json'
        Use-GerberUserConfigurationPathMock -ConfigPath $configPath
        Mock Get-Content { throw [System.UnauthorizedAccessException]::new('Access denied.') } -ParameterFilter {
            $LiteralPath -eq $configPath
        }

        { Get-GerberUserConfiguration } | Should -Throw "*'$configPath'*"
    }

    It 'does not expose configuration values in validation errors' {
        $null = Get-GerberUserConfigurationTestFile `
            -RelativePath 'user/config.json' `
            -Content '{ "token": "super-secret-value" }'

        try {
            $null = Get-GerberUserConfiguration
            throw 'Expected Get-GerberUserConfiguration to fail.'
        } catch {
            $_.Exception.Message | Should -Match 'schemaVersion'
            $_.Exception.Message | Should -Not -Match 'super-secret-value'
        }
    }
}
