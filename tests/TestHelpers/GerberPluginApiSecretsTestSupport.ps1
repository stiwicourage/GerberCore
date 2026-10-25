function Get-TestGerberPluginCredentialStore {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Account,

        [Parameter(Mandatory)]
        [string]$Secret
    )

    $store = [pscustomobject]@{
        Account = $Account
        Secret = $Secret
        LastReadAccount = $null
        LastWrittenAccount = $null
        LastRemovedAccount = $null
    }
    $store | Add-Member ScriptMethod GetAccounts {
        param($service)
        $null = $service
        if ($null -eq $this.Secret) {
            return @()
        }

        return @($this.Account)
    }
    $store | Add-Member ScriptMethod Get {
        param($service, $account)
        $null = $service
        $this.LastReadAccount = $account
        if ($null -eq $this.Secret) {
            return $null
        }

        return [pscustomobject]@{ Password = $this.Secret }
    }
    $store | Add-Member ScriptMethod AddOrUpdate {
        param($service, $account, $secret)
        $null = $service
        $this.LastWrittenAccount = $account
        $this.Account = $account
        $this.Secret = $secret
    }
    $store | Add-Member ScriptMethod Remove {
        param($service, $account)
        $null = $service
        $this.LastRemovedAccount = $account
        $this.Secret = $null
        return $true
    }

    return $store
}

function Invoke-TestGerberPluginSecretsRoundTrip {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [string[]]$PathSegmentList = @('tools', 'plugin-tool', 'secret', 'client-u'),

        [string]$ActionLabel = 'test plugin secret callbacks',

        [string]$ScreenTitle = '/tools plugin-tool',

        [string]$UpdatedSecret = 'updated-secret'
    )

    $pluginModule = New-Module -Name PluginConsumer -ScriptBlock {
        param($Gerber, $ResolvedPathSegmentList, $ResolvedActionLabel, $ResolvedScreenTitle, $ResolvedUpdatedSecret)
        $pluginContext = $Gerber
        $pathSegmentList = $ResolvedPathSegmentList
        $actionLabel = $ResolvedActionLabel
        $screenTitle = $ResolvedScreenTitle
        $updatedSecret = $ResolvedUpdatedSecret

        <#
        .SYNOPSIS
        Exercises plugin secret callbacks from an external module.
        #>
        function Invoke-PluginSecretsRoundTrip {
            $ready = & $pluginContext.Secrets.EnsureReady $actionLabel $screenTitle
            $before = & $pluginContext.Secrets.GetText $pathSegmentList
            & $pluginContext.Secrets.Set $pathSegmentList $updatedSecret | Out-Null
            $after = & $pluginContext.Secrets.GetText $pathSegmentList
            & $pluginContext.Secrets.Remove $pathSegmentList | Out-Null
            $existsAfterRemove = & $pluginContext.Secrets.Test $pathSegmentList

            return [pscustomobject]@{
                Ready = $ready
                Before = $before
                After = $after
                ExistsAfterRemove = $existsAfterRemove
            }
        }

        Export-ModuleMember -Function Invoke-PluginSecretsRoundTrip
    } -ArgumentList $Context, $PathSegmentList, $ActionLabel, $ScreenTitle, $UpdatedSecret
    Import-Module $pluginModule -Force | Out-Null

    return PluginConsumer\Invoke-PluginSecretsRoundTrip
}

function Invoke-TestGerberBuiltPluginSecretsRoundTrip {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.PSModuleInfo]$Module
    )

    $storeFactory = ${function:Get-TestGerberPluginCredentialStore}

    return & $Module {
        param($Factory)

        $store = & $Factory `
            -Account 'gerber:plugin:977537c5-b7f5-4f2f-9dd4-5ec0e28d2618:tests:integration:callback-scope' `
            -Secret 'first-value'
        $script:GerberCredentialStore = $store
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId ([guid]'977537c5-b7f5-4f2f-9dd4-5ec0e28d2618')
        $consumer = New-Module -Name PluginConsumer -ScriptBlock {
            param($Gerber)
            $pluginContext = $Gerber

            <#
            .SYNOPSIS
            Exercises plugin secret callbacks from an external module.
            #>
            function Invoke-PluginSecretsRoundTrip {
                $pathSegmentList = @('tests', 'integration', 'callback-scope')
                $ready = & $pluginContext.Secrets.EnsureReady 'integration test' '/tools bearer-token'
                $before = & $pluginContext.Secrets.GetText $pathSegmentList
                & $pluginContext.Secrets.Set $pathSegmentList 'updated-value' | Out-Null
                $after = & $pluginContext.Secrets.GetText $pathSegmentList
                & $pluginContext.Secrets.Remove $pathSegmentList | Out-Null
                $existsAfterRemove = & $pluginContext.Secrets.Test $pathSegmentList

                return [pscustomobject]@{
                    Ready = $ready
                    Before = $before
                    After = $after
                    ExistsAfterRemove = $existsAfterRemove
                }
            }

            Export-ModuleMember -Function Invoke-PluginSecretsRoundTrip
        } -ArgumentList $context
        Import-Module $consumer -Force | Out-Null

        $state = PluginConsumer\Invoke-PluginSecretsRoundTrip
        $state | Add-Member -NotePropertyName LastReadAccount -NotePropertyValue $store.LastReadAccount
        $state | Add-Member -NotePropertyName LastWrittenAccount -NotePropertyValue $store.LastWrittenAccount
        $state | Add-Member -NotePropertyName LastRemovedAccount -NotePropertyValue $store.LastRemovedAccount
        return $state
    } $storeFactory
}
