BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Show-GerberPluginInfoView' {
    BeforeEach {
        $script:pluginInfoText = $null
        Mock Wait-GerberContinue {}
        Mock Show-GerberTextBlock { $script:pluginInfoText = $Text }
    }

    It 'shows plugin information by GUID' {
        $plugin = [pscustomobject]@{
            Guid = '6996218c-58d0-48ce-b6cc-38d06149230a'
            Name = 'Gerber.TestPlugin'
            DisplayName = 'Gerber.TestPlugin'
            Version = '1.0.0'
            Description = 'Fixture plugin'
            Author = 'Fixture Publisher'
            CompanyName = 'Fixture Company'
            ModulePath = '/tmp/Gerber.TestPlugin/Gerber.TestPlugin.psd1'
            ApprovalStatus = 'Approved'
            IsAssociated = $true
            IsEnabled = $true
            State = 'Enabled'
            Loaded = $true
            RegisteredNamespaceList = @('example')
            RegisteredCommandList = @('example')
        }

        Show-GerberPluginInfoView -Plugin $plugin

        $script:pluginInfoText | Should -Match 'Plugin: Gerber\.TestPlugin'
        $script:pluginInfoText | Should -Match 'GUID:\s+6996218c-58d0-48ce-b6cc-38d06149230a'
        $script:pluginInfoText | Should -Match 'Approval:\s+Approved'
        $script:pluginInfoText | Should -Match 'Namespaces:\s+/example'
        $script:pluginInfoText | Should -Match 'Commands:\s+/example'
        Should -Invoke Wait-GerberContinue -Times 1
    }

    It 'shows the declined-state note for a declined plugin' {
        $plugin = [pscustomobject]@{
            Guid = '11111111-2222-3333-4444-555555555555'
            Name = 'Gerber.Example'
            DisplayName = 'Gerber.Example'
            Version = '0.1.0'
            Description = 'Fixture plugin'
            Author = 'Fixture Publisher'
            CompanyName = $null
            ModulePath = '/tmp/Gerber.Example/Gerber.Example.psd1'
            ApprovalStatus = 'Declined'
            IsAssociated = $false
            IsEnabled = $true
            State = 'Discovered'
            Loaded = $false
            RegisteredNamespaceList = @()
            RegisteredCommandList = @()
        }

        Show-GerberPluginInfoView -Plugin $plugin

        $script:pluginInfoText | Should -Match 'Approval:\s+Declined'
        $script:pluginInfoText | Should -Match 'will not be loaded or prompt for approval automatically'
    }

    It 'returns to the caller when the info view is dismissed with escape in selection mode' {
        Mock Wait-GerberContinue { throw (Get-GerberMenuEscapeException) }

        {
            Show-GerberPluginInfoView `
                -Plugin ([pscustomobject]@{
                    Guid = '6996218c-58d0-48ce-b6cc-38d06149230a'
                    Name = 'Gerber.TestPlugin'
                    DisplayName = 'Gerber.TestPlugin'
                    Version = '1.0.0'
                    Description = 'Fixture plugin'
                    Author = 'Fixture Publisher'
                    CompanyName = 'Fixture Company'
                    ModulePath = '/tmp/Gerber.TestPlugin/Gerber.TestPlugin.psd1'
                    ApprovalStatus = 'Approved'
                    IsAssociated = $true
                    IsEnabled = $true
                    State = 'Enabled'
                    Loaded = $true
                    RegisteredNamespaceList = @('example')
                    RegisteredCommandList = @('example')
                }) `
                -ReturnToSelectionOnEscape
        } | Should -Not -Throw
    }
}
