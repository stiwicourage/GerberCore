BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
    $script:inactivePlugin = [pscustomobject]@{
        Guid = '6996218c-58d0-48ce-b6cc-38d06149230a'; DisplayName = 'Gerber.TestPlugin'; Version = '1.0.0'
        ApprovalStatus = 'Declined'; State = 'Discovered'; IsDiscovered = $true; Loaded = $false
    }
    $script:activePlugin = [pscustomobject]@{
        Guid = 'ba17d0cb-cfea-4cb8-8fcb-fb0d27e8d3a5'; DisplayName = 'Gerber.SecondTestPlugin'; Version = '1.0.0'
        ApprovalStatus = 'Approved'; State = 'Enabled'; IsDiscovered = $true; Loaded = $true
    }
}

Describe 'Invoke-GerberPluginsEnableCommand' {
    BeforeEach {
        Mock Get-GerberPluginInventory { @($script:inactivePlugin, $script:activePlugin) }
        Mock Show-GerberTextBlock {}
        Mock Wait-GerberContinue {}
        Mock Enable-GerberPlugin {}
    }

    It 'offers only inactive plugins and enables the selection' {
        Mock Read-GerberNumberedMenuPrompt { $MenuItemList.Count | Should -Be 1; $MenuItemList[0].Value }

        Invoke-GerberPluginsEnableCommand

        Should -Invoke Enable-GerberPlugin -Times 1 -ParameterFilter { $Guid -eq $script:inactivePlugin.Guid }
        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter { $Text -like "Enabled and approved plugin 'Gerber.TestPlugin'*" }
    }

    It 'leaves state unchanged when selection is cancelled' {
        Mock Read-GerberNumberedMenuPrompt { throw (Get-GerberMenuEscapeException) }

        { Invoke-GerberPluginsEnableCommand } | Should -Not -Throw

        Should -Invoke Enable-GerberPlugin -Times 0
    }

    It 'reports when no plugin is available to enable' {
        Mock Get-GerberPluginInventory { @($script:activePlugin) }
        Mock Read-GerberNumberedMenuPrompt {}

        Invoke-GerberPluginsEnableCommand

        Should -Invoke Read-GerberNumberedMenuPrompt -Times 0
        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter { $Text -like 'No installed Gerber plugins*' }
    }

    It 'surfaces activation failures to the menu loop without reporting success' {
        Mock Read-GerberNumberedMenuPrompt { $MenuItemList[0].Value }
        Mock Enable-GerberPlugin { throw [System.InvalidOperationException]::new('load failed') }

        { Invoke-GerberPluginsEnableCommand } | Should -Throw '*load failed*'

        Should -Invoke Show-GerberTextBlock -Times 0
    }

    It 'rejects extra arguments' {
        { Invoke-GerberPluginsEnableCommand -Command ([pscustomobject]@{ Arguments = @('x') }) } |
            Should -Throw "*does not accept extra arguments*"
    }
}

Describe 'Invoke-GerberPluginsDisableCommand' {
    BeforeEach {
        Mock Get-GerberPluginInventory { @($script:inactivePlugin, $script:activePlugin) }
        Mock Show-GerberTextBlock {}
        Mock Wait-GerberContinue {}
        Mock Disable-GerberPlugin {}
    }

    It 'offers only loaded plugins and disables the selection' {
        Mock Read-GerberNumberedMenuPrompt { $MenuItemList.Count | Should -Be 1; $MenuItemList[0].Value }

        Invoke-GerberPluginsDisableCommand

        Should -Invoke Disable-GerberPlugin -Times 1 -ParameterFilter { $Guid -eq $script:activePlugin.Guid }
    }

    It 'leaves state unchanged when selection is cancelled' {
        Mock Read-GerberNumberedMenuPrompt { throw (Get-GerberMenuEscapeException) }

        { Invoke-GerberPluginsDisableCommand } | Should -Not -Throw

        Should -Invoke Disable-GerberPlugin -Times 0
    }

    It 'reports when no plugin is enabled' {
        Mock Get-GerberPluginInventory { @($script:inactivePlugin) }

        Invoke-GerberPluginsDisableCommand

        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter { $Text -like 'No enabled Gerber plugins*' }
    }
}

Describe 'Invoke-GerberPluginsAliasCommand' {
    BeforeEach {
        Mock Get-GerberPluginInventory { @($script:inactivePlugin, $script:activePlugin) }
        Mock Show-GerberTextBlock {}
        Mock Wait-GerberContinue {}
        Mock Set-GerberPluginNamespaceAlias {}
        Mock Read-GerberNumberedMenuPrompt { $script:activePlugin.Guid }
    }

    It 'stores the entered alias for the selected plugin GUID' {
        Mock Read-GerberCommand { 'microsoft-ado' }

        Invoke-GerberPluginsAliasCommand

        Should -Invoke Set-GerberPluginNamespaceAlias -Times 1 -ParameterFilter {
            $Guid -eq $script:activePlugin.Guid -and $Alias -eq 'microsoft-ado'
        }
        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter { $Text -like "*'/microsoft-ado'*restart*" }
    }

    It 'removes the alias when the input is empty' {
        Mock Read-GerberCommand { '' }

        Invoke-GerberPluginsAliasCommand

        Should -Invoke Set-GerberPluginNamespaceAlias -Times 1 -ParameterFilter { [string]::IsNullOrEmpty($Alias) }
        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter { $Text -like 'Removed*alias*' }
    }

    It 'asks again when the alias is rejected' {
        $script:aliasAnswers = [System.Collections.Queue]::new(@('plugins', 'ok-name'))
        Mock Read-GerberCommand { $script:aliasAnswers.Dequeue() }
        Mock Set-GerberPluginNamespaceAlias { if ($Alias -eq 'plugins') { throw [System.ArgumentException]::new('reserved') } }

        Invoke-GerberPluginsAliasCommand

        Should -Invoke Set-GerberPluginNamespaceAlias -Times 2
        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter { $Text -like '*reserved*' }
    }

    It 'leaves aliases unchanged when selection is cancelled' {
        Mock Read-GerberNumberedMenuPrompt { throw (Get-GerberMenuEscapeException) }

        { Invoke-GerberPluginsAliasCommand } | Should -Not -Throw

        Should -Invoke Set-GerberPluginNamespaceAlias -Times 0
    }

    It 'leaves aliases unchanged when the alias prompt is cancelled' {
        Mock Read-GerberCommand { throw (Get-GerberMenuEscapeException) }

        { Invoke-GerberPluginsAliasCommand } | Should -Not -Throw

        Should -Invoke Set-GerberPluginNamespaceAlias -Times 0
    }
}
