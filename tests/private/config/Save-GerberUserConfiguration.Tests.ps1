BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot

    function Use-GerberSavedConfigurationPathMock {
        param(
            [Parameter(Mandatory)]
            [string]$ConfigPath
        )

        $script:GerberSavedConfigurationPath = $ConfigPath
        Mock Resolve-GerberUserConfigPath { $script:GerberSavedConfigurationPath }
    }

    function Get-GerberSavedConfigurationPath {
        param(
            [string]$RelativePath = 'user/config.json'
        )

        return (Join-Path $TestDrive $RelativePath)
    }

    function Use-GerberExistingConfigurationFile {
        param(
            [Parameter(Mandatory)]
            [string]$ConfigPath,

            [string]$Content = '{ "schemaVersion": 1, "theme": "light" }'
        )

        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $ConfigPath) -Force
        Set-Content -LiteralPath $ConfigPath -Value $Content
    }
}

Describe 'Save-GerberUserConfiguration' {
    It 'persists a valid configuration' {
        $configPath = Get-GerberSavedConfigurationPath
        Use-GerberSavedConfigurationPathMock -ConfigPath $configPath

        Save-GerberUserConfiguration -Configuration @{
            schemaVersion = 1
            preferences = @{
                theme = 'dark'
            }
        }

        (Test-Path -LiteralPath $configPath) | Should -BeTrue
        ((Get-Content -LiteralPath $configPath -Raw) | ConvertFrom-Json -AsHashtable).preferences.theme | Should -Be 'dark'
    }

    It 'round-trips the persisted configuration through the reader' {
        $configPath = Get-GerberSavedConfigurationPath
        Use-GerberSavedConfigurationPathMock -ConfigPath $configPath
        $configuration = @{
            schemaVersion = 1
            preferences = @{
                theme = 'dark'
            }
        }

        Save-GerberUserConfiguration -Configuration $configuration
        $result = Get-GerberUserConfiguration

        $result.preferences.theme | Should -Be 'dark'
    }

    It 'preserves unknown properties across a save and read cycle' {
        $configPath = Get-GerberSavedConfigurationPath
        Use-GerberSavedConfigurationPathMock -ConfigPath $configPath
        $configuration = @{
            schemaVersion = 1
            customSection = @{
                value = 'kept'
            }
            list = @('one', 'two')
        }

        Save-GerberUserConfiguration -Configuration $configuration
        $result = Get-GerberUserConfiguration

        $result.customSection.value | Should -Be 'kept'
        @($result.list) | Should -Be @('one', 'two')
    }

    It 'does not write an invalid configuration' {
        $configPath = Get-GerberSavedConfigurationPath -RelativePath 'invalid/user/config.json'
        Use-GerberSavedConfigurationPathMock -ConfigPath $configPath

        { Save-GerberUserConfiguration -Configuration @{ } } | Should -Throw "*schemaVersion*"
        (Test-Path -LiteralPath $configPath) | Should -BeFalse
    }

    It 'keeps an existing configuration when saving fails before replacement' -ForEach @(
        @{
            SetupMocks = { }
            FailureConfiguration = @{ theme = 'dark' }
            ErrorMessage = '*schemaVersion*'
        }
        @{
            SetupMocks = { Mock ConvertTo-GerberUserConfigurationJson { throw 'Serialization failed.' } }
            FailureConfiguration = @{ schemaVersion = 1 }
            ErrorMessage = '*Serialization failed.*'
        }
        @{
            SetupMocks = { Mock Write-GerberUserConfigurationFileContent { throw 'Disk full.' } }
            FailureConfiguration = @{ schemaVersion = 1 }
            ErrorMessage = '*Disk full.*'
        }
    ) {
        param($SetupMocks, $FailureConfiguration, $ErrorMessage)

        $configPath = Get-GerberSavedConfigurationPath
        $configurationToSave = $FailureConfiguration
        Use-GerberExistingConfigurationFile -ConfigPath $configPath
        Use-GerberSavedConfigurationPathMock -ConfigPath $configPath
        & $SetupMocks

        { Save-GerberUserConfiguration -Configuration $configurationToSave } | Should -Throw $ErrorMessage
        (Get-Content -LiteralPath $configPath -Raw) | Should -Match '"theme": "light"'
    }

    It 'keeps an existing configuration and cleans up the temporary file when replacement fails' {
        $configPath = Get-GerberSavedConfigurationPath
        $tempPath = Join-Path $TestDrive 'user/config.json.tmp'
        Use-GerberExistingConfigurationFile -ConfigPath $configPath
        Use-GerberSavedConfigurationPathMock -ConfigPath $configPath
        Mock Get-GerberUserConfigurationTemporaryPath { $tempPath }
        Mock Publish-GerberUserConfigurationTemporaryFile { throw 'Rename failed.' }

        { Save-GerberUserConfiguration -Configuration @{ schemaVersion = 1; theme = 'dark' } } | Should -Throw '*Rename failed.*'

        (Get-Content -LiteralPath $configPath -Raw) | Should -Match '"theme": "light"'
        (Test-Path -LiteralPath $tempPath) | Should -BeFalse
    }

    It 'cleans up temporary files after a successful save' {
        $configPath = Get-GerberSavedConfigurationPath
        $configDirectory = Split-Path -Parent $configPath
        Use-GerberSavedConfigurationPathMock -ConfigPath $configPath

        Save-GerberUserConfiguration -Configuration @{ schemaVersion = 1 }

        @(Get-ChildItem -LiteralPath $configDirectory -Filter '*.tmp' -ErrorAction SilentlyContinue) | Should -BeNullOrEmpty
    }

    It 'creates the destination directory only when saving' {
        $configPath = Get-GerberSavedConfigurationPath -RelativePath 'user/nested/config.json'
        $configDirectory = Split-Path -Parent $configPath
        Use-GerberSavedConfigurationPathMock -ConfigPath $configPath

        (Test-Path -LiteralPath $configDirectory) | Should -BeFalse

        Save-GerberUserConfiguration -Configuration @{ schemaVersion = 1 }

        (Test-Path -LiteralPath $configDirectory) | Should -BeTrue
    }

    It 'creates Unix configuration files with owner-only read and write permissions where supported' -Skip:$IsWindows {
        $configPath = Get-GerberSavedConfigurationPath
        Use-GerberSavedConfigurationPathMock -ConfigPath $configPath

        Save-GerberUserConfiguration -Configuration @{ schemaVersion = 1 }

        ([int](Get-Item -LiteralPath $configPath).UnixFileMode) | Should -Be ([int][System.IO.UnixFileMode]'UserRead, UserWrite')
    }
}
