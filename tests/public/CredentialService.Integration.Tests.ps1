BeforeAll {
    . (Join-Path (Split-Path -Parent $PSScriptRoot) 'TestHelpers/GerberPluginApiSecretsTestSupport.ps1')
}

Describe 'Gerber credential service integration' {
    It 'packages the CredentialManager assemblies with the built module' {
        $moduleBase = Resolve-Path (Join-Path $PSScriptRoot '../../dist/Gerber')
        $libraryPath = Join-Path $moduleBase 'resources/lib'

        Test-Path -LiteralPath (Join-Path $libraryPath 'Devlooped.CredentialManager.dll') |
            Should -BeTrue
        Test-Path -LiteralPath (Join-Path $libraryPath 'DotNetConfig.dll') |
            Should -BeTrue
    }

    It 'excludes legacy credential modules while retaining both required runtime dependencies' {
        $module = Get-Module -Name Gerber -ErrorAction Stop
        $requiredModuleNameList = @($module.RequiredModules | ForEach-Object Name)

        $requiredModuleNameList | Should -Not -Contain 'Microsoft.PowerShell.SecretManagement'
        $requiredModuleNameList | Should -Not -Contain 'Microsoft.PowerShell.SecretStore'
        $requiredModuleNameList | Should -Contain 'NovaModuleTools'
        $requiredModuleNameList | Should -Contain 'PSModuleUpdate'
    }

    It 'imports Gerber without loading or accessing CredentialManager' {
        [type]::GetType(
            'GitCredentialManager.CredentialManager, Devlooped.CredentialManager',
            $false
        ) | Should -BeNullOrEmpty
    }

    It 'round-trips an isolated native credential when explicitly enabled' -Tag 'NativeCredentialStore' -Skip:(
        $env:GERBER_RUN_NATIVE_CREDENTIAL_TESTS -ne '1'
    ) {
        $modulePath = Join-Path $PSScriptRoot '../../dist/Gerber/Gerber.psd1'
        $module = Import-Module -Name $modulePath -Force -PassThru
        $identifier = 'gerber:test:integration:{0}' -f [guid]::NewGuid().ToString('N')
        $created = $false
        try {
            & $module {
                param($id)
                Set-GerberCredential -Identifier $id -Secret 'first-value' | Out-Null
            } $identifier
            $created = $true
            & $module {
                param($id)
                Get-GerberCredential -Identifier $id
            } $identifier | Should -Be 'first-value'

            & $module {
                param($id)
                Set-GerberCredential -Identifier $id -Secret 'updated-value' | Out-Null
                Get-GerberCredential -Identifier $id
            } $identifier | Should -Be 'updated-value'
        } finally {
            if ($created) {
                & $module {
                    param($id)
                    Remove-GerberCredential -Identifier $id | Out-Null
                } $identifier
            }
        }

        & $module {
            param($id)
            Test-GerberCredential -Identifier $id
        } $identifier | Should -BeFalse
    }

    It 'keeps plugin secrets callbacks bound to the built Gerber module across an external module boundary' {
        $modulePath = Join-Path $PSScriptRoot '../../dist/Gerber/Gerber.psd1'
        $module = Import-Module -Name $modulePath -Force -PassThru

        $result = Invoke-TestGerberBuiltPluginSecretsRoundTrip -Module $module

        $result.Ready | Should -BeTrue
        $result.Before | Should -Be 'first-value'
        $result.After | Should -Be 'updated-value'
        $result.ExistsAfterRemove | Should -BeFalse
        $result.LastReadAccount | Should -Be 'gerber:plugin:977537c5-b7f5-4f2f-9dd4-5ec0e28d2618:tests:integration:callback-scope'
        $result.LastWrittenAccount | Should -Be 'gerber:plugin:977537c5-b7f5-4f2f-9dd4-5ec0e28d2618:tests:integration:callback-scope'
        $result.LastRemovedAccount | Should -Be 'gerber:plugin:977537c5-b7f5-4f2f-9dd4-5ec0e28d2618:tests:integration:callback-scope'
    }

    It 'round-trips an isolated native plugin credential when explicitly enabled' -Tag 'NativeCredentialStore' -Skip:(
        $env:GERBER_RUN_NATIVE_CREDENTIAL_TESTS -ne '1'
    ) {
        $modulePath = Join-Path $PSScriptRoot '../../dist/Gerber/Gerber.psd1'
        $module = Import-Module -Name $modulePath -Force -PassThru
        $pathSegmentList = @('tests', 'native-plugin-credential', [guid]::NewGuid().ToString('N'))
        try {
            $state = & $module {
                param($logicalPathSegmentList)

                $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId ([guid]'977537c5-b7f5-4f2f-9dd4-5ec0e28d2618')
                $consumer = New-Module -Name NativePluginConsumer -ScriptBlock {
                    param($Gerber)
                    $pluginContext = $Gerber

                    <#
                    .SYNOPSIS
                    Exercises native plugin credential callbacks from an external module.
                    #>
                    function Invoke-NativePluginCredentialRoundTrip {
                        param($PathSegmentList)

                        $identifier = 'gerber:plugin:977537c5-b7f5-4f2f-9dd4-5ec0e28d2618:{0}' -f ($PathSegmentList -join ':')
                        & $pluginContext.Secrets.EnsureReady 'native plugin credential test' '/tools bearer-token' | Out-Null
                        & $pluginContext.Secrets.Remove $PathSegmentList | Out-Null
                        & $pluginContext.Secrets.Set $PathSegmentList 'first-value' | Out-Null
                        $existsAfterCreate = [bool](& $pluginContext.Secrets.Test $PathSegmentList)
                        $firstValue = & $pluginContext.Secrets.GetText $PathSegmentList
                        & $pluginContext.Secrets.Set $PathSegmentList 'updated-value' | Out-Null
                        $updatedValue = & $pluginContext.Secrets.GetText $PathSegmentList
                        & $pluginContext.Secrets.Remove $PathSegmentList | Out-Null
                        $existsAfterRemove = [bool](& $pluginContext.Secrets.Test $PathSegmentList)

                        return [pscustomobject]@{
                            Identifier = $identifier
                            ExistsAfterCreate = $existsAfterCreate
                            FirstValue = $firstValue
                            UpdatedValue = $updatedValue
                            ExistsAfterRemove = $existsAfterRemove
                        }
                    }

                    Export-ModuleMember -Function Invoke-NativePluginCredentialRoundTrip
                } -ArgumentList $context
                Import-Module $consumer -Force | Out-Null
                return NativePluginConsumer\Invoke-NativePluginCredentialRoundTrip -PathSegmentList $logicalPathSegmentList
            } $pathSegmentList

            $state.Identifier | Should -Match '^gerber:plugin:977537c5-b7f5-4f2f-9dd4-5ec0e28d2618:tests:native-plugin-credential:'
            $state.ExistsAfterCreate | Should -BeTrue
            $state.FirstValue | Should -Be 'first-value'
            $state.UpdatedValue | Should -Be 'updated-value'
            $state.ExistsAfterRemove | Should -BeFalse
        } finally {
            & $module {
                param($logicalPathSegmentList)

                $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId ([guid]'977537c5-b7f5-4f2f-9dd4-5ec0e28d2618')
                $consumer = New-Module -Name NativePluginCleanup -ScriptBlock {
                    param($Gerber)
                    $pluginContext = $Gerber

                    <#
                    .SYNOPSIS
                    Removes the native plugin test credential.
                    #>
                    function Invoke-NativePluginCredentialCleanup {
                        param($PathSegmentList)
                        & $pluginContext.Secrets.Remove $PathSegmentList | Out-Null
                    }

                    Export-ModuleMember -Function Invoke-NativePluginCredentialCleanup
                } -ArgumentList $context
                Import-Module $consumer -Force | Out-Null
                NativePluginCleanup\Invoke-NativePluginCredentialCleanup -PathSegmentList $logicalPathSegmentList
            } $pathSegmentList
        }
    }
}
