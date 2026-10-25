Set-StrictMode -Version Latest

$script:resolvedCommandCaseList = @(
    @{ CommandPath = '/tools create-uuid'; ExpectedRootName = 'tools'; ExpectedArguments = @('create-uuid') }
    @{ CommandPath = '/tools base-64'; ExpectedRootName = 'tools'; ExpectedArguments = @('base-64') }
    @{ CommandPath = '/tools base-64 encode'; ExpectedRootName = 'tools'; ExpectedArguments = @('base-64', 'encode') }
    @{ CommandPath = '/tools base-64 decode'; ExpectedRootName = 'tools'; ExpectedArguments = @('base-64', 'decode') }
    @{ CommandPath = '/list ado-agents'; ExpectedRootName = 'list'; ExpectedArguments = @('ado-agents') }
    @{ CommandPath = '/list ado-team-members'; ExpectedRootName = 'list'; ExpectedArguments = @('ado-team-members') }
    @{ CommandPath = '/branch find'; ExpectedRootName = 'branch'; ExpectedArguments = @('find') }
    @{ CommandPath = '/branch set-default'; ExpectedRootName = 'branch'; ExpectedArguments = @('set-default') }
    @{ CommandPath = '/branch set-searchable'; ExpectedRootName = 'branch'; ExpectedArguments = @('set-searchable') }
    @{ CommandPath = '/repository create'; ExpectedRootName = 'repository'; ExpectedArguments = @('create') }
    @{ CommandPath = '/plugins list'; ExpectedRootName = 'plugins'; ExpectedArguments = @('list') }
    @{ CommandPath = '/plugins info Gerber.TestPlugin'; ExpectedRootName = 'plugins'; ExpectedArguments = @('info', 'Gerber.TestPlugin') }
    @{ CommandPath = '/pipelines tags'; ExpectedRootName = 'pipelines'; ExpectedArguments = @('tags') }
    @{ CommandPath = '/pipelines tags delete'; ExpectedRootName = 'pipelines'; ExpectedArguments = @('tags', 'delete') }
    @{ CommandPath = '/pipelines tags update'; ExpectedRootName = 'pipelines'; ExpectedArguments = @('tags', 'update') }
    @{ CommandPath = '/secrets list'; ExpectedRootName = 'secrets'; ExpectedArguments = @('list') }
    @{ CommandPath = '/secrets get'; ExpectedRootName = 'secrets'; ExpectedArguments = @('get') }
    @{ CommandPath = '/secrets test'; ExpectedRootName = 'secrets'; ExpectedArguments = @('test') }
    @{ CommandPath = '/secrets set'; ExpectedRootName = 'secrets'; ExpectedArguments = @('set') }
    @{ CommandPath = '/secrets remove'; ExpectedRootName = 'secrets'; ExpectedArguments = @('remove') }
)

$script:registeredMenuLeafNameList = @(
    'tools create-uuid',
    'tools base-64',
    'list ado-agents',
    'list ado-team-members',
    'repository create',
    'plugins list',
    'plugins info',
    'pipelines tags'
)

$script:internalActionCommandNameList = @(
    'tools base-64 encode',
    'tools base-64 decode',
    'branch find',
    'branch set-default',
    'branch set-searchable',
    'pipelines tags delete',
    'pipelines tags update',
    'secrets list',
    'secrets test',
    'secrets get',
    'secrets set',
    'secrets remove'
)

BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Gerber command reachability' {
    It 'resolves representative core command paths through the live command resolver' -ForEach $script:resolvedCommandCaseList {
        param($CommandPath, $ExpectedRootName, $ExpectedArguments)

        $result = Resolve-GerberCommand -InputText $CommandPath

        $result.IsValid | Should -BeTrue
        $result.Name | Should -Be $ExpectedRootName
        $result.Arguments | Should -Be $ExpectedArguments
    }

    It 'keeps registry-driven menu leaf commands registered in the live registry' {
        $missingCommandNameList = [System.Collections.Generic.List[string]]::new()
        foreach ($commandName in $script:registeredMenuLeafNameList) {
            if ($null -eq (Get-GerberRegisteredCommand -Name $commandName)) {
                $missingCommandNameList.Add($commandName)
            }
        }

        @($missingCommandNameList) | Should -Be @()
    }

    It 'keeps internally dispatched action commands out of the registry' -ForEach $script:internalActionCommandNameList {
        (Get-GerberRegisteredCommand -Name $_) | Should -BeNullOrEmpty
    }

    It 'detects missing registry-driven menu leaf commands through in-memory registry manipulation' {
        $registeredCommandList = @(
            Get-GerberCommandRegistry |
                Where-Object { $_.Name -notin @('repository create', 'pipelines tags') }
        )
        $registeredCommandNameList = @($registeredCommandList.Name)

        $registeredCommandNameList | Should -Not -Contain 'repository create'
        $registeredCommandNameList | Should -Not -Contain 'pipelines tags'
    }

    It 'routes direct invocation of registry-driven menu commands through the live registry' -ForEach @(
        @{ RootName = 'tools'; Subcommand = 'create-uuid'; MockTarget = 'Show-GerberCreateUuidTool' }
        @{ RootName = 'list'; Subcommand = 'ado-agents'; MockTarget = 'Invoke-GerberListAdoAgentsCommand' }
        @{ RootName = 'repository'; Subcommand = 'create'; MockTarget = 'Show-GerberRepositoryCreateView' }
        @{ RootName = 'plugins'; Subcommand = 'list'; MockTarget = 'Invoke-GerberPluginsListCommand' }
        @{ RootName = 'pipelines'; Subcommand = 'tags'; MockTarget = 'Show-GerberPipelinesTagsView' }
    ) {
        param($RootName, $Subcommand, $MockTarget)

        Mock Show-GerberCreateUuidTool {}
        Mock Invoke-GerberListAdoAgentsCommand {}
        Mock Show-GerberRepositoryCreateView {}
        Mock Invoke-GerberPluginsListCommand {}
        Mock Show-GerberPipelinesTagsView {}

        $subcommandName = Get-GerberMenuSubcommand `
            -CommandName $RootName `
            -Command ([pscustomobject]@{
                Arguments = [string[]]@($Subcommand)
            })
        $registeredCommand = Get-GerberRegisteredSubcommandDefinition -CommandName $RootName -Subcommand $subcommandName

        Invoke-GerberRegisteredSubcommand -RegisteredCommand $registeredCommand -Arguments @($Subcommand)

        Should -Invoke $MockTarget -Times 1
    }

    It 'routes interactive registry-driven menus through the live registry' -ForEach @(
        @{ ViewFunction = 'Show-GerberToolsView'; SelectedSubcommand = 'create-uuid'; MockTarget = 'Show-GerberCreateUuidTool' }
        @{ ViewFunction = 'Show-GerberListView'; SelectedSubcommand = 'ado-agents'; MockTarget = 'Invoke-GerberListAdoAgentsCommand' }
        @{ ViewFunction = 'Show-GerberRepositoryView'; SelectedSubcommand = 'create'; MockTarget = 'Show-GerberRepositoryCreateView' }
        @{ ViewFunction = 'Show-GerberPipelinesView'; SelectedSubcommand = 'tags'; MockTarget = 'Show-GerberPipelinesTagsView' }
    ) {
        param($ViewFunction, $SelectedSubcommand, $MockTarget)

        $selectedSubcommandName = $SelectedSubcommand
        $script:subcommandSelectionCount = 0
        Mock Get-GerberMenuSubcommand {
            $script:subcommandSelectionCount++
            if ($script:subcommandSelectionCount -eq 1) {
                return $selectedSubcommandName
            }

            return ''
        }
        Mock Show-GerberCreateUuidTool {}
        Mock Invoke-GerberListAdoAgentsCommand {}
        Mock Show-GerberRepositoryCreateView {}
        Mock Show-GerberPipelinesTagsView {}

        & $ViewFunction ([pscustomobject]@{ Arguments = @() })

        Should -Invoke $MockTarget -Times 1
    }
}
