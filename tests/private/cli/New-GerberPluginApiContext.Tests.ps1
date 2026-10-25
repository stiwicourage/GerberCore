BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberPluginApiAdoTestSupport.ps1')
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberPluginApiSecretsTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'New-GerberPluginApiContext' {
    BeforeEach {
        $script:testPluginId = [guid]'977537c5-b7f5-4f2f-9dd4-5ec0e28d2618'
        Remove-Variable -Name GerberCredentialStore -Scope Script -ErrorAction SilentlyContinue
    }

    It 'creates the v1 plugin API context with the declared API version and capability set' {
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        $context.ApiVersion | Should -Be '1'
        $context.PluginId | Should -Be $script:testPluginId
        $context.UI.ReadSubcommand | Should -BeOfType ([scriptblock])
        $context.UI.ShowTextBlock | Should -BeOfType ([scriptblock])
        $context.UI.ShowScreenLines | Should -BeOfType ([scriptblock])
        $context.UI.ReadNumberedMenuSelection | Should -BeOfType ([scriptblock])
        $context.UI.ReadNumberedMenuPrompt | Should -BeOfType ([scriptblock])
        $context.UI.ReadCheckboxMenuPrompt | Should -BeOfType ([scriptblock])
        $context.UI.ReadConfirmationPrompt | Should -BeOfType ([scriptblock])
        $context.UI.ReadCommand | Should -BeOfType ([scriptblock])
        $context.UI.ReadSecretText | Should -BeOfType ([scriptblock])
        $context.UI.StartScreen | Should -BeOfType ([scriptblock])
        $context.UI.WriteScreenLine | Should -BeOfType ([scriptblock])
        $context.UI.WriteProgressBar | Should -BeOfType ([scriptblock])
        $context.UI.WritePromptTrace | Should -BeOfType ([scriptblock])
        $context.UI.WaitForContinue | Should -BeOfType ([scriptblock])
        $context.Ado.OpenConnection | Should -BeOfType ([scriptblock])
        $context.Ado.ResolvePullRequestReference | Should -BeOfType ([scriptblock])
        $context.Ado.GetPullRequest | Should -BeOfType ([scriptblock])
        $context.Ado.GetPullRequestChangedFileList | Should -BeOfType ([scriptblock])
        $context.Ado.GetPullRequestFileContent | Should -BeOfType ([scriptblock])
        $context.Ado.GetPullRequestBuildValidationStatus | Should -BeOfType ([scriptblock])
        $context.Ado.NewProjectUri | Should -BeOfType ([scriptblock])
        $context.Ado.InvokeGet | Should -BeOfType ([scriptblock])
        $context.Ado.GetPendingApprovalList | Should -BeOfType ([scriptblock])
        $context.Ado.GetEnvironmentList | Should -BeOfType ([scriptblock])
        $context.Ado.ResolvePipelineDefinitionFromUrl | Should -BeOfType ([scriptblock])
        $context.Ado.GetPipelineRunList | Should -BeOfType ([scriptblock])
        $context.Ado.StartPipelineRun | Should -BeOfType ([scriptblock])
        $context.Ado.WaitPipelineRunCompletion | Should -BeOfType ([scriptblock])
        $context.Ado.ApprovePipelineApproval | Should -BeOfType ([scriptblock])
        $context.Ado.StopPipelineRun | Should -BeOfType ([scriptblock])
        $context.Ado.GetBuildTagList | Should -BeOfType ([scriptblock])
        $context.Ado.AddBuildTagIfMissing | Should -BeOfType ([scriptblock])
        $context.Ado.RemoveBuildTag | Should -BeOfType ([scriptblock])
        $context.Ado.AddBuildRetentionLeaseIfMissing | Should -BeOfType ([scriptblock])
        $context.Ado.GetBuildRunUrl | Should -BeOfType ([scriptblock])
        $context.Ado.GetWorkItemIdFromUrl | Should -BeOfType ([scriptblock])
        $context.Ado.GetWorkItemFieldMap | Should -BeOfType ([scriptblock])
        $context.Ado.UpdateWorkItemFields | Should -BeOfType ([scriptblock])
        $context.Secrets.EnsureReady | Should -BeOfType ([scriptblock])
        $context.Secrets.Test | Should -BeOfType ([scriptblock])
        $context.Secrets.GetText | Should -BeOfType ([scriptblock])
        $context.Secrets.Set | Should -BeOfType ([scriptblock])
        $context.Secrets.Remove | Should -BeOfType ([scriptblock])
        $context.Clipboard.CopyText | Should -BeOfType ([scriptblock])
    }

    It 'fails clearly for an unsupported plugin API version' {
        {
            New-GerberPluginApiContext -ApiVersion '99' -PluginId $script:testPluginId
        } | Should -Throw "Gerber plugin API version '99' is not supported. Supported plugin API versions: 1."
    }

    It 'maps UI prompt operations to the shared Gerber helpers' {
        Mock Read-GerberSubcommandPrompt { '/tools plugin-tool option-b' }
        Mock Read-GerberNumberedMenuPrompt { 'value-2' }
        Mock Read-GerberCheckboxMenuPrompt { [pscustomobject]@{ SelectedItemList = @(); DeselectedItemList = @() } }
        Mock Read-GerberConfirmationPrompt { $true }
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        (& $context.UI.ReadSubcommand 'tools plugin-tool' ([pscustomobject]@{ Arguments = @() }) ([ordered]@{ 'option-b' = 'Option B' })) | Should -Be 'option-b'
        (& $context.UI.ReadNumberedMenuSelection 'Prompt' '/tools plugin-tool option-b' 'Choose one' @(
                [pscustomobject]@{ Number = 1; Label = 'One'; Value = 'value-1'; PreviewText = '' }
                [pscustomobject]@{ Number = 2; Label = 'Two'; Value = 'value-2'; PreviewText = '' }
            )) | Should -Be 'value-2'
        (& $context.UI.ReadNumberedMenuPrompt 'Prompt' '/tools plugin-tool option-b' 'Choose one' @()) | Should -Be 'value-2'
        (& $context.UI.ReadCheckboxMenuPrompt ([pscustomobject]@{ Prompt = 'Prompt' })) | Should -Not -BeNullOrEmpty
        (& $context.UI.ReadConfirmationPrompt 'Confirm' 'Title' 'Body' ([pscustomobject]@{})) | Should -BeTrue

        Should -Invoke Read-GerberSubcommandPrompt -Times 1 -ParameterFilter { $CommandName -eq 'tools plugin-tool' }
        Should -Invoke Read-GerberNumberedMenuPrompt -Times 1 -ParameterFilter {
            $Prompt -eq 'Prompt' -and
            $ScreenTitle -eq '/tools plugin-tool option-b' -and
            $ScreenText -eq 'Choose one' -and
            $MenuItemList[1].Value -eq 'value-2'
        }
        Should -Invoke Read-GerberCheckboxMenuPrompt -Times 1 -ParameterFilter { $PromptRequest.Prompt -eq 'Prompt' }
        Should -Invoke Read-GerberConfirmationPrompt -Times 1 -ParameterFilter { $Prompt -eq 'Confirm' -and $ScreenTitle -eq 'Title' }
    }

    It 'maps UI rendering operations to the shared Gerber helpers' {
        Mock Show-GerberTextBlock {}
        Mock Start-GerberScreen {}
        Mock Write-GerberScreenLine {}
        Mock Write-GerberProgressBar {}
        Mock Write-GerberPromptTrace {}
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        & $context.UI.ShowTextBlock 'Title' 'Body'
        & $context.UI.ShowScreenLines '/tools plugin-tool option-b' @('first', '', 'second')
        & $context.UI.StartScreen '/tools plugin-tool option-b'
        & $context.UI.WriteScreenLine 'line'
        & $context.UI.WriteProgressBar 1 2 'Prefix'
        & $context.UI.WritePromptTrace 'event' @{ ok = $true }

        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter { $Title -eq 'Title' -and $Text -eq 'Body' }
        Should -Invoke Start-GerberScreen -Times 2 -ParameterFilter { $Name -eq '/tools plugin-tool option-b' }
        Should -Invoke Write-GerberScreenLine -Times 4
        Should -Invoke Write-GerberProgressBar -Times 1 -ParameterFilter { $Current -eq 1 -and $Total -eq 2 -and $Prefix -eq 'Prefix' }
        Should -Invoke Write-GerberPromptTrace -Times 1 -ParameterFilter { $EventName -eq 'event' -and $Data.ok }
    }

    It 'allows plugins to render an empty text block body' {
        Mock Show-GerberTextBlock {}
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        { & $context.UI.ShowTextBlock 'Title' '' } | Should -Not -Throw

        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter { $Title -eq 'Title' -and $Text -eq '' }
    }

    It 'maps UI command and secret operations to the shared Gerber helpers' {
        Mock Read-GerberCommand { 'typed-value' }
        Mock Read-GerberSecureValue {
            $secureValue = [System.Security.SecureString]::new()
            foreach ($character in 'secret-value'.ToCharArray()) {
                $secureValue.AppendChar($character)
            }

            $secureValue.MakeReadOnly()
            return $secureValue
        }
        Mock Wait-GerberContinue {}
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        (& $context.UI.ReadCommand 'Prompt' 'None' 'Buffered' $null $true) | Should -Be 'typed-value'
        (& $context.UI.ReadSecretText 'Plugin secret') | Should -Be 'secret-value'
        (& $context.UI.WaitForContinue) | Should -BeTrue

        Should -Invoke Read-GerberCommand -Times 1 -ParameterFilter { $Prompt -eq 'Prompt' -and $SuggestionMode -eq 'None' }
        Should -Invoke Read-GerberSecureValue -Times 1 -ParameterFilter { $Prompt -eq 'Plugin secret' }
        Should -Invoke Wait-GerberContinue -Times 1
    }

    It 'returns neutral UI results when Escape is used in plugin-driven prompts' {
        Mock Read-GerberSubcommandPrompt { throw (Get-GerberMenuEscapeException) }
        Mock Read-GerberNumberedMenuPrompt { throw (Get-GerberMenuEscapeException) }
        Mock Read-GerberSecureValue { throw (Get-GerberMenuEscapeException) }
        Mock Wait-GerberContinue { throw (Get-GerberMenuEscapeException) }
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        (& $context.UI.ReadSubcommand 'tools plugin-tool' ([pscustomobject]@{ Arguments = @() }) ([ordered]@{})) | Should -Be ''
        (& $context.UI.ReadNumberedMenuSelection 'Prompt' '/tools plugin-tool option-b' 'Choose one' @()) | Should -BeNullOrEmpty
        (& $context.UI.ReadSecretText 'Plugin secret') | Should -BeNullOrEmpty
        (& $context.UI.WaitForContinue) | Should -BeFalse
    }

    It 'maps credential capability operations to the plugin GUID namespace' {
        $expectedIdentifier = 'gerber:plugin:977537c5-b7f5-4f2f-9dd4-5ec0e28d2618:tools:plugin-tool:secret:client-u'
        $store = [pscustomobject]@{
            Account = $expectedIdentifier
            Secret = 'stored-secret'
            LastService = $null
            LastReadAccount = $null
            LastWrittenAccount = $null
            LastRemovedAccount = $null
        }
        $store | Add-Member ScriptMethod GetAccounts { @($this.Account) }
        $store | Add-Member ScriptMethod Get {
            param($service, $account)
            $this.LastService = $service
            $this.LastReadAccount = $account
            if ($null -eq $this.Secret) {
                return $null
            }

            return [pscustomobject]@{ Password = $this.Secret }
        }
        $store | Add-Member ScriptMethod AddOrUpdate {
            param($service, $account, $secret)
            $this.LastService = $service
            $this.LastWrittenAccount = $account
            $this.Account = $account
            $this.Secret = $secret
        }
        $store | Add-Member ScriptMethod Remove {
            param($service, $account)
            $this.LastService = $service
            $this.LastRemovedAccount = $account
            $this.Secret = $null
            return $true
        }
        $script:GerberCredentialStore = $store
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        (& $context.Secrets.EnsureReady 'run a plugin action' '/tools plugin-tool option-a') | Should -BeTrue
        (& $context.Secrets.GetText @('tools', 'plugin-tool', 'secret', 'client-u')) | Should -Be 'stored-secret'
        $store.LastReadAccount | Should -Be $expectedIdentifier
        (& $context.Secrets.Test @('tools', 'plugin-tool', 'secret', 'client-u')) | Should -BeTrue
        & $context.Secrets.Set @('tools', 'plugin-tool', 'secret', 'client-u') 'new-secret'
        $store.LastService | Should -Be 'credentials'
        $store.LastWrittenAccount | Should -Be $expectedIdentifier
        $store.Secret | Should -Be 'new-secret'
        (& $context.Secrets.Remove @('tools', 'plugin-tool', 'secret', 'client-u')) | Should -BeTrue
        $store.LastRemovedAccount | Should -Be $expectedIdentifier
        $store.Secret | Should -BeNullOrEmpty
    }

    It 'keeps plugin secret callbacks bound to the Gerber module session state when invoked from an external module' {
        $store = Get-TestGerberPluginCredentialStore `
            -Account 'gerber:plugin:977537c5-b7f5-4f2f-9dd4-5ec0e28d2618:tools:plugin-tool:secret:client-u' `
            -Secret 'stored-secret'
        $script:GerberCredentialStore = $store
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId
        $result = Invoke-TestGerberPluginSecretsRoundTrip -Context $context

        $result.Ready | Should -BeTrue
        $result.Before | Should -Be 'stored-secret'
        $result.After | Should -Be 'updated-secret'
        $result.ExistsAfterRemove | Should -BeFalse
        $store.LastReadAccount | Should -Be 'gerber:plugin:977537c5-b7f5-4f2f-9dd4-5ec0e28d2618:tools:plugin-tool:secret:client-u'
        $store.LastWrittenAccount | Should -Be 'gerber:plugin:977537c5-b7f5-4f2f-9dd4-5ec0e28d2618:tools:plugin-tool:secret:client-u'
        $store.LastRemovedAccount | Should -Be 'gerber:plugin:977537c5-b7f5-4f2f-9dd4-5ec0e28d2618:tools:plugin-tool:secret:client-u'
    }

    It 'surfaces Gerber-specific secure storage errors for plugin secret readiness checks' {
        Mock Get-GerberCredentialInfo {
            throw [System.InvalidOperationException]::new(
                'Gerber could not initialize secure credential storage. Verify that secure credential storage is available for your user account, then try again.'
            )
        }
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        $errorText = $null
        try {
            & $context.Secrets.EnsureReady 'run a plugin action' '/tools plugin-tool option-a' | Out-Null
        } catch {
            $errorText = $_.Exception.ToString()
        }

        $errorText | Should -Match 'secure credential storage'
        $errorText | Should -Not -Match 'Devlooped'
    }

    It 'rejects empty secret path segment lists' {
        {
            Get-GerberPluginCredentialIdentifier -PluginId $script:testPluginId -PathSegmentList @()
        } | Should -Throw 'Gerber plugin API secret operations require at least one path segment.'
    }

    It 'maps ADO connection and request operations to shared Core infrastructure without exposing PAT values' {
        Mock Get-GerberAdoConfiguration { Get-TestGerberPluginApiAdoConfiguration }
        Mock Resolve-GerberAdoPat { 'resolved-pat' }
        Mock Get-GerberAdoApiUri { [uri]'https://dev.azure.com/example-org/SampleProject/_apis/wiki/wikis/SampleProject.wiki/pages?path=%2FCDM-Dependencies&api-version=7.0' }
        Mock Invoke-GerberAdoRestRequest { [pscustomobject]@{ content = 'value' } }
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        $connection = & $context.Ado.OpenConnection '/list common-data-model'
        $requestUri = & $context.Ado.NewProjectUri $connection 'SampleProject/_apis/wiki/wikis/SampleProject.wiki/pages' ([ordered]@{
                path = '/CDM-Dependencies'
            })
        $response = & $context.Ado.InvokeGet $connection $requestUri 'the Common Data Model feed list'

        $connection.PSObject.Properties.Name | Should -Be @(
            'Id',
            'CommandLabel',
            'ProfileName',
            'DeploymentType',
            'ServerUri',
            'Organization',
            'Collection',
            'CollectionName',
            'CollectionUri',
            'ProjectName',
            'ProjectUri'
        )
        $connection.ProfileName | Should -Be 'EXAMPLE'
        $connection.ProjectName | Should -Be 'SampleProject'
        $connection.ProjectUri.AbsoluteUri | Should -Be 'https://dev.azure.com/example-org/SampleProject'
        $connection.PSObject.Properties.Name | Should -Not -Contain 'Pat'
        $connection.PSObject.Properties.Name | Should -Not -Contain 'Token'
        $connection.PSObject.Properties.Name | Should -Not -Contain 'CredentialIdentifier'
        $requestUri.AbsoluteUri | Should -Be 'https://dev.azure.com/example-org/SampleProject/_apis/wiki/wikis/SampleProject.wiki/pages?path=%2FCDM-Dependencies&api-version=7.0'
        $response.content | Should -Be 'value'

        Should -Invoke Get-GerberAdoConfiguration -Times 1 -ParameterFilter {
            $CommandLabel -eq '/list common-data-model'
        }
        Should -Invoke Resolve-GerberAdoPat -Times 1 -ParameterFilter {
            $Configuration.ProfileName -eq 'EXAMPLE' -and
            $CommandLabel -eq '/list common-data-model'
        }
        Should -Invoke Get-GerberAdoApiUri -Times 1 -ParameterFilter {
            $BaseUri.AbsoluteUri -eq 'https://dev.azure.com/example-org/SampleProject/_apis/wiki/wikis/SampleProject.wiki/pages' -and
            $QueryParameterMap.path -eq '/CDM-Dependencies' -and
            $QueryParameterMap['api-version'] -eq '7.0'
        }
        Should -Invoke Invoke-GerberAdoRestRequest -Times 1 -ParameterFilter {
            $Uri.AbsoluteUri -eq $requestUri.AbsoluteUri -and
            $Pat -eq 'resolved-pat' -and
            $RequestLabel -eq 'the Common Data Model feed list' -and
            $PatAccountIdentifier -eq 'gerber:ado:EXAMPLE:pat'
        }
    }

    It 'maps ADO pull-request operations to shared Core infrastructure without exposing configuration or PAT values' {
        Mock Get-GerberAdoConfiguration { Get-TestGerberPluginApiAdoConfiguration }
        Mock Resolve-GerberAdoPat { 'resolved-pat' }
        Mock Resolve-GerberAdoPullRequestReference { [pscustomobject]@{ PullRequestId = 18075 } }
        Mock Get-GerberAdoPullRequest { [pscustomobject]@{ PullRequestId = 18075; RepositoryName = 'Repo' } }
        Mock Get-GerberAdoPullRequestChangedFileList { @([pscustomobject]@{ Path = '/azure-pipelines.yml'; ChangeType = 'edit' }) }
        Mock Get-GerberAdoPullRequestFileContent { 'trigger: none' }
        Mock Get-GerberAdoPullRequestBuildValidationStatus { [pscustomobject]@{ IsAvailable = $true; StatusList = @(); ErrorMessage = '' } }
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        $connection = Get-TestGerberPluginApiAdoConnection

        $outcome = [pscustomobject]@{
            Reference = (& $context.Ado.ResolvePullRequestReference $connection '18075')
        }
        $outcome | Add-Member -NotePropertyName PullRequest -NotePropertyValue (& $context.Ado.GetPullRequest $connection $outcome.Reference)
        $outcome | Add-Member -NotePropertyName ChangedFileList -NotePropertyValue (& $context.Ado.GetPullRequestChangedFileList $connection $outcome.PullRequest)
        $outcome | Add-Member -NotePropertyName Content -NotePropertyValue (& $context.Ado.GetPullRequestFileContent $connection $outcome.PullRequest '/azure-pipelines.yml' $true)
        $outcome | Add-Member -NotePropertyName BuildValidation -NotePropertyValue (& $context.Ado.GetPullRequestBuildValidationStatus $connection $outcome.PullRequest)

        Assert-TestGerberPluginApiPullRequestOperationSet -Outcome $outcome
    }

    It 'maps ADO planning operations to shared Core infrastructure' {
        Mock Get-GerberAdoConfiguration { Get-TestGerberPluginApiAdoConfiguration }
        Mock Resolve-GerberAdoPat { 'resolved-pat' }
        Mock Get-GerberAdoPendingApprovalList { @([pscustomobject]@{ ApprovalId = '1' }) }
        Mock Get-GerberAdoEnvironmentList { @([pscustomobject]@{ Id = 1; Name = 'U1' }) }
        Mock Resolve-GerberAdoPipelineDefinitionFromUrl { [pscustomobject]@{ Id = 42; Name = 'Pipeline' } }
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        $connection = Get-TestGerberPluginApiAdoConnection
        $pendingApprovals = & $context.Ado.GetPendingApprovalList $connection 0
        $environmentList = & $context.Ado.GetEnvironmentList $connection
        $definition = & $context.Ado.ResolvePipelineDefinitionFromUrl $connection ([uri]'https://dev.azure.com/example-org/SampleProject/_build?definitionId=42')

        $pendingApprovals[0].ApprovalId | Should -Be '1'
        $environmentList[0].Name | Should -Be 'U1'
        $definition.Name | Should -Be 'Pipeline'

        Should -Invoke Get-GerberAdoPendingApprovalList -Times 1 -ParameterFilter { $Configuration.ProjectName -eq 'SampleProject' -and $Pat -eq 'resolved-pat' }
        Should -Invoke Get-GerberAdoEnvironmentList -Times 1 -ParameterFilter { $Configuration.ProjectName -eq 'SampleProject' -and $Pat -eq 'resolved-pat' }
        Should -Invoke Resolve-GerberAdoPipelineDefinitionFromUrl -Times 1 -ParameterFilter { $Configuration.ProjectName -eq 'SampleProject' -and $Pat -eq 'resolved-pat' }
    }

    It 'maps ADO run operations to shared Core infrastructure' {
        Mock Get-GerberAdoConfiguration { Get-TestGerberPluginApiAdoConfiguration }
        Mock Resolve-GerberAdoPat { 'resolved-pat' }
        Mock Get-GerberAdoPipelineRunList { @([pscustomobject]@{ BuildId = 1 }) }
        Mock Start-GerberAdoPipelineRun { [pscustomobject]@{ BuildId = 2 } }
        Mock Wait-GerberAdoPipelineRunCompletion { [pscustomobject]@{ BuildId = 2; Status = 'completed' } }
        Mock Approve-GerberAdoPipelineApproval {}
        Mock Stop-GerberAdoPipelineRun {}
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        $connection = Get-TestGerberPluginApiAdoConnection
        $runList = & $context.Ado.GetPipelineRunList ([pscustomobject]@{ Connection = $connection; DefinitionId = 42; BranchName = 'main' })
        $startedRun = & $context.Ado.StartPipelineRun ([pscustomobject]@{ Connection = $connection; DefinitionId = 42; BranchName = 'main'; Fixversion = '1.0.0' })
        $completedRun = & $context.Ado.WaitPipelineRunCompletion ([pscustomobject]@{ Connection = $connection; BuildId = 2 })
        & $context.Ado.ApprovePipelineApproval $connection '1' 'ok'
        & $context.Ado.StopPipelineRun $connection 2

        $runList[0].BuildId | Should -Be 1
        $startedRun.BuildId | Should -Be 2
        $completedRun.Status | Should -Be 'completed'

        Should -Invoke Get-GerberAdoPipelineRunList -Times 1 -ParameterFilter { $RunListRequest.Configuration.ProjectName -eq 'SampleProject' }
        Should -Invoke Start-GerberAdoPipelineRun -Times 1 -ParameterFilter { $RunRequest.Configuration.ProjectName -eq 'SampleProject' }
        Should -Invoke Wait-GerberAdoPipelineRunCompletion -Times 1 -ParameterFilter { $RunWaitRequest.Configuration.ProjectName -eq 'SampleProject' }
        Should -Invoke Approve-GerberAdoPipelineApproval -Times 1 -ParameterFilter { $Configuration.ProjectName -eq 'SampleProject' -and $ApprovalId -eq '1' }
        Should -Invoke Stop-GerberAdoPipelineRun -Times 1 -ParameterFilter { $Configuration.ProjectName -eq 'SampleProject' -and $BuildId -eq 2 }
    }

    It 'maps ADO build tag operations to shared Core infrastructure' {
        Mock Get-GerberAdoConfiguration { Get-TestGerberPluginApiAdoConfiguration }
        Mock Resolve-GerberAdoPat { 'resolved-pat' }
        Mock Get-GerberAdoBuildTagList { @('tag-a') }
        Mock Add-GerberAdoBuildTagIfMissing { $true }
        Mock Remove-GerberAdoBuildTag {}
        Mock Add-GerberAdoBuildRetentionLeaseIfMissing { $true }
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        $connection = Get-TestGerberPluginApiAdoConnection
        $tagList = & $context.Ado.GetBuildTagList $connection 2
        $null = & $context.Ado.AddBuildTagIfMissing $connection 2 'tag-a'
        & $context.Ado.RemoveBuildTag $connection 2 'tag-a'
        $null = & $context.Ado.AddBuildRetentionLeaseIfMissing $connection 42 2

        $tagList | Should -Be @('tag-a')

        Should -Invoke Get-GerberAdoBuildTagList -Times 1 -ParameterFilter { $Configuration.ProjectName -eq 'SampleProject' -and $BuildId -eq 2 }
        Should -Invoke Add-GerberAdoBuildTagIfMissing -Times 1 -ParameterFilter { $Configuration.ProjectName -eq 'SampleProject' -and $Tag -eq 'tag-a' }
        Should -Invoke Remove-GerberAdoBuildTag -Times 1 -ParameterFilter { $Configuration.ProjectName -eq 'SampleProject' -and $Tag -eq 'tag-a' }
        Should -Invoke Add-GerberAdoBuildRetentionLeaseIfMissing -Times 1 -ParameterFilter { $Configuration.ProjectName -eq 'SampleProject' -and $DefinitionId -eq 42 -and $BuildId -eq 2 }
    }

    It 'maps ADO build run URL and work-item operations to shared Core infrastructure' {
        Mock Get-GerberAdoConfiguration { Get-TestGerberPluginApiAdoConfiguration }
        Mock Resolve-GerberAdoPat { 'resolved-pat' }
        Mock Get-GerberAdoBuildRunUrl { 'https://dev.azure.com/example-org/SampleProject/_build/results?buildId=2&view=results' }
        Mock Get-GerberAdoWorkItemIdFromUrl { 123 }
        Mock Get-GerberAdoWorkItemFieldMap { @{ 'Custom.StepByStepGuide' = 'Guide' } }
        Mock Update-GerberAdoWorkItemFieldMap {}
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        $connection = Get-TestGerberPluginApiAdoConnection
        $runUrl = & $context.Ado.GetBuildRunUrl $connection 2
        $workItemId = & $context.Ado.GetWorkItemIdFromUrl 'https://dev.azure.com/example-org/SampleProject/_workitems/edit/123'
        $fieldMap = & $context.Ado.GetWorkItemFieldMap ([pscustomobject]@{ Connection = $connection; WorkItemId = 123 })
        & $context.Ado.UpdateWorkItemFields ([pscustomobject]@{
                Connection    = $connection
                WorkItemId    = 123
                FieldValueMap = [ordered]@{ 'Custom.StatusiProd' = 'Completed' }
            })

        $runUrl | Should -Match 'buildId=2'
        $workItemId | Should -Be 123
        $fieldMap['Custom.StepByStepGuide'] | Should -Be 'Guide'

        Should -Invoke Get-GerberAdoBuildRunUrl -Times 1 -ParameterFilter { $Configuration.ProjectName -eq 'SampleProject' -and $BuildId -eq 2 }
        Should -Invoke Get-GerberAdoWorkItemIdFromUrl -Times 1 -ParameterFilter { $WorkItemUrl -match '/123$' }
        Should -Invoke Get-GerberAdoWorkItemFieldMap -Times 1 -ParameterFilter { $WorkItemRequest.Configuration.ProjectName -eq 'SampleProject' -and $WorkItemRequest.WorkItemId -eq 123 }
        Should -Invoke Update-GerberAdoWorkItemFieldMap -Times 1 -ParameterFilter {
            $UpdateRequest.Configuration.ProjectName -eq 'SampleProject' -and
            $UpdateRequest.FieldValueMap['Custom.StatusiProd'] -eq 'Completed'
        }
    }

    It 'keeps plugin ADO callbacks bound to the Gerber module session state when invoked from an external module' {
        Mock Get-GerberAdoConfiguration { Get-TestGerberPluginApiAdoConfiguration }
        Mock Resolve-GerberAdoPat { 'resolved-pat' }
        Mock Get-GerberAdoBuildRunUrl { 'https://dev.azure.com/example-org/SampleProject/_build/results?buildId=2&view=results' }
        Mock Get-GerberAdoApiUri { [uri]'https://dev.azure.com/example-org/SampleProject/_apis/wiki/wikis/SampleProject.wiki/pages?api-version=7.0' }
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId
        $pluginModule = New-Module -Name PluginAdoConsumer -ScriptBlock {
            param($Gerber)
            $pluginContext = $Gerber

            <#
            .SYNOPSIS
            Exercises plugin ADO callbacks from an external module.
            #>
            function Invoke-PluginAdoRoundTrip {
                $connection = & $pluginContext.Ado.OpenConnection '/repository review'
                $uri = & $pluginContext.Ado.NewProjectUri $connection '_apis/wiki/wikis/SampleProject.wiki/pages'
                $runUrl = & $pluginContext.Ado.GetBuildRunUrl $connection 2

                return [pscustomobject]@{
                    ProfileName = $connection.ProfileName
                    RequestUri = $uri.AbsoluteUri
                    RunUrl = $runUrl
                }
            }

            Export-ModuleMember -Function Invoke-PluginAdoRoundTrip
        } -ArgumentList $context
        Import-Module $pluginModule -Force | Out-Null

        $result = PluginAdoConsumer\Invoke-PluginAdoRoundTrip

        $result.ProfileName | Should -Be 'EXAMPLE'
        $result.RequestUri | Should -Be 'https://dev.azure.com/example-org/SampleProject/_apis/wiki/wikis/SampleProject.wiki/pages?api-version=7.0'
        $result.RunUrl | Should -Match 'buildId=2'
        Should -Invoke Get-GerberAdoConfiguration -Times 1 -ParameterFilter { $CommandLabel -eq '/repository review' }
        Should -Invoke Resolve-GerberAdoPat -Times 0
        Should -Invoke Get-GerberAdoBuildRunUrl -Times 1 -ParameterFilter { $BuildId -eq 2 }
    }

    It 'allows callers to override the default ADO api-version when creating project URIs' {
        Mock Get-GerberAdoConfiguration { Get-TestGerberPluginApiAdoConfiguration }
        Mock Resolve-GerberAdoPat { throw 'Authentication should not be required for URI creation.' }
        Mock Get-GerberAdoApiUri { [uri]'https://dev.azure.com/example-org/_apis/test?api-version=7.1-preview.1' }
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        $connection = Get-TestGerberPluginApiAdoConnection
        $null = & $context.Ado.NewProjectUri $connection '_apis/test' ([ordered]@{
                'api-version' = '7.1-preview.1'
            })

        Should -Invoke Get-GerberAdoApiUri -Times 1 -ParameterFilter {
            $QueryParameterMap['api-version'] -eq '7.1-preview.1'
        }
        Should -Invoke Resolve-GerberAdoPat -Times 0
    }

    It 'rejects plugin ADO requests that do not use a connection created by the capability' {
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        {
            & $context.Ado.InvokeGet ([pscustomobject]@{}) ([uri]'https://dev.azure.com/example-org/test') 'request'
        } | Should -Throw 'Gerber plugin ADO operations require a connection created by Gerber.Ado.OpenConnection.'
    }

    It 'surfaces an actionable error when an authenticated plugin operation finds a missing PAT' {
        Mock Get-GerberAdoConfiguration { Get-TestGerberPluginApiAdoConfiguration }
        Mock Resolve-GerberAdoPat {
            throw [System.ArgumentException]::new(
                "Gerber could not continue /list common-data-model because the PAT is missing."
            )
        }
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId
        $connection = Get-TestGerberPluginApiAdoConnection -CommandLabel '/list common-data-model'

        {
            & $context.Ado.InvokeGet $connection ([uri]'https://dev.azure.com/example-org/SampleProject/_apis/test') 'test request'
        } | Should -Throw '*PAT is missing*'
    }

    It 'supports opening an explicit named connection without resolving credentials eagerly' {
        Mock Get-GerberAdoConfiguration {
            [pscustomobject]@{
                ProfileName            = 'SampleProject'
                DeploymentType         = 'Services'
                ServerUri              = [uri]'https://dev.azure.com'
                Organization           = 'example-org'
                Collection             = ''
                CollectionName         = 'example-org'
                CollectionUri          = [uri]'https://dev.azure.com/example-org/'
                ProjectName            = 'Atlas'
                ProjectUri             = [uri]'https://dev.azure.com/example-org/Atlas'
                DefaultApiVersion      = '7.0'
                CredentialIdentifier   = 'gerber:ado:SampleProject:pat'
            }
        }
        Mock Resolve-GerberAdoPat { throw 'OpenConnection should not resolve PAT values.' }
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        $connection = & $context.Ado.OpenConnection '/repository review' 'sampleproject'

        $connection.ProfileName | Should -Be 'SampleProject'
        $connection.ProjectName | Should -Be 'Atlas'
        Should -Invoke Get-GerberAdoConfiguration -Times 1 -ParameterFilter {
            $ProfileName -eq 'sampleproject' -and
            $CommandLabel -eq '/repository review'
        }
        Should -Invoke Resolve-GerberAdoPat -Times 0
    }

    It 'keeps multiple plugin ADO connections isolated by profile and credential' {
        Mock Get-GerberAdoConfiguration {
            if ($null -ne $ConnectionProfile) {
                if ($ConnectionProfile.ProfileName -eq 'ATLAS') {
                    return [pscustomobject]@{
                        ProfileName            = 'ATLAS'
                        DeploymentType         = 'Services'
                        ServerUri              = [uri]'https://dev.azure.com'
                        Organization           = 'example-org'
                        Collection             = ''
                        CollectionName         = 'example-org'
                        CollectionUri          = [uri]'https://dev.azure.com/example-org/'
                        ProjectName            = 'Atlas'
                        ProjectUri             = [uri]'https://dev.azure.com/example-org/Atlas'
                        DefaultApiVersion      = '7.0'
                        CredentialIdentifier   = 'gerber:ado:ATLAS:pat'
                    }
                }

                if ($ConnectionProfile.ProfileName -eq 'EXAMPLE') {
                    return Get-TestGerberPluginApiAdoConfiguration
                }

                return [pscustomobject]@{
                    ProfileName            = $ConnectionProfile.ProfileName
                    DeploymentType         = 'Services'
                    ServerUri              = [uri]'https://dev.azure.com'
                    Organization           = 'example-org'
                    Collection             = ''
                    CollectionName         = 'example-org'
                    CollectionUri          = [uri]'https://dev.azure.com/example-org/'
                    ProjectName            = $ConnectionProfile.Project
                    ProjectUri             = [uri]$ConnectionProfile.ProjectUri
                    DefaultApiVersion      = '7.0'
                    CredentialIdentifier   = "gerber:ado:$($ConnectionProfile.ProfileName):pat"
                }
            }

            return Get-TestGerberPluginApiAdoConfiguration
        }
        Mock Resolve-GerberAdoPat {
            if ($Configuration.ProfileName -eq 'EXAMPLE') {
                return 'example-pat'
            }

            return 'atlas-pat'
        }
        Mock Invoke-GerberAdoRestRequest {
            [pscustomobject]@{
                Pat                  = $Pat
                PatAccountIdentifier = $PatAccountIdentifier
            }
        }
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        $exampleConnection = Get-TestGerberPluginApiAdoConnection -CommandLabel '/repository review' -ProfileName 'EXAMPLE' -ProjectName 'SampleProject'
        $atlasConnection = Get-TestGerberPluginApiAdoConnection -CommandLabel '/list common-data-model' -ProfileName 'ATLAS' -ProjectName 'Atlas'

        $exampleResponse = & $context.Ado.InvokeGet $exampleConnection ([uri]'https://dev.azure.com/example-org/SampleProject/_apis/test') 'example request'
        $atlasResponse = & $context.Ado.InvokeGet $atlasConnection ([uri]'https://dev.azure.com/example-org/Atlas/_apis/test') 'atlas request'

        Should -Invoke Resolve-GerberAdoPat -Times 2
        Should -Invoke Invoke-GerberAdoRestRequest -Times 2
        $exampleResponse.Pat | Should -Be 'example-pat'
        $exampleResponse.PatAccountIdentifier | Should -Be 'gerber:ado:EXAMPLE:pat'
        $atlasResponse.Pat | Should -Be 'atlas-pat'
        $atlasResponse.PatAccountIdentifier | Should -Be 'gerber:ado:ATLAS:pat'
    }

    It 'does not require authentication for metadata-only connection operations' {
        Mock Get-GerberAdoConfiguration { Get-TestGerberPluginApiAdoConfiguration }
        Mock Resolve-GerberAdoPat { throw 'Metadata-only operations should not resolve PAT values.' }
        Mock Get-GerberAdoBuildRunUrl { 'https://dev.azure.com/example-org/SampleProject/_build/results?buildId=2&view=results' }
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId
        $connection = Get-TestGerberPluginApiAdoConnection

        $runUrl = & $context.Ado.GetBuildRunUrl $connection 2

        $runUrl | Should -Match 'buildId=2'
        Should -Invoke Resolve-GerberAdoPat -Times 0
    }

    It 'maps the clipboard capability to shared Core infrastructure' {
        Mock Copy-GerberValueToClipboard { [pscustomobject]@{ Success = $true; Message = 'Copied.' } }
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        $clipboardResult = & $context.Clipboard.CopyText 'token-value'

        $clipboardResult.Success | Should -BeTrue
        Should -Invoke Copy-GerberValueToClipboard -Times 1 -ParameterFilter { $Value -eq 'token-value' }
    }
}
