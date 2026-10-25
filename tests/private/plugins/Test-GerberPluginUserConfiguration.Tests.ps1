BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot

    function Get-GerberPluginConfigurationValidationConfiguration {
        param(
            [Parameter(Mandatory)]
            [hashtable]$Plugins
        )

        return @{
            schemaVersion = 1
            plugins = $Plugins
        }
    }
}

Describe 'Test-GerberPluginUserConfiguration' {
    It 'accepts valid plugin approval and lifecycle records' -ForEach @(
        @{
            Plugins = @{
                approved = @('977537c5-b7f5-4f2f-9dd4-5ec0e28d2618')
            }
        }
        @{
            Plugins = @{
                declined = @('977537c5-b7f5-4f2f-9dd4-5ec0e28d2618')
            }
        }
        @{
            Plugins = @{
                associated = @{
                    '977537c5-b7f5-4f2f-9dd4-5ec0e28d2618' = @{
                        enabled = $false
                    }
                }
            }
        }
    ) {
        param($Plugins)

        $configuration = Get-GerberPluginConfigurationValidationConfiguration -Plugins $Plugins

        {
            Test-GerberPluginUserConfiguration -Configuration $configuration -Path '/tmp/config.json'
        } | Should -Not -Throw
    }

    It 'rejects malformed plugin approval and lifecycle records' -ForEach @(
        @{
            Plugins = @{
                approved = @('not-a-guid')
            }
            ErrorMessage = "*plugins.approved*valid GUID*"
        }
        @{
            Plugins = @{
                approved = @(
                    '977537c5-b7f5-4f2f-9dd4-5ec0e28d2618'
                    '977537C5-B7F5-4F2F-9DD4-5EC0E28D2618'
                )
            }
            ErrorMessage = "*duplicate GUID*"
        }
        @{
            Plugins = @{
                declined = @('not-a-guid')
            }
            ErrorMessage = "*plugins.declined*valid GUID*"
        }
        @{
            Plugins = @{
                declined = @(
                    '977537c5-b7f5-4f2f-9dd4-5ec0e28d2618'
                    '977537C5-B7F5-4F2F-9DD4-5EC0E28D2618'
                )
            }
            ErrorMessage = "*plugins.declined*duplicate GUID*"
        }
        @{
            Plugins = @{
                associated = @{
                    'not-a-guid' = @{
                        enabled = $true
                    }
                }
            }
            ErrorMessage = "*plugins.associated*valid GUID*"
        }
        @{
            Plugins = @{
                associated = @{
                    '977537c5-b7f5-4f2f-9dd4-5ec0e28d2618' = @{
                        enabled = 'yes'
                    }
                }
            }
            ErrorMessage = "*plugins.associated*enabled*Boolean*"
        }
    ) {
        param($Plugins, $ErrorMessage)

        $configuration = Get-GerberPluginConfigurationValidationConfiguration -Plugins $Plugins

        {
            Test-GerberPluginUserConfiguration -Configuration $configuration -Path '/tmp/config.json'
        } | Should -Throw $ErrorMessage
    }
}
