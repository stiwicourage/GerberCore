BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    foreach ($path in @('Show-GerberUpdateBatchView', 'Read-GerberUpdateItemSelection', 'Read-GerberUpdateInspectionConsent', 'Get-GerberUpdateBatchConsentText', 'Show-GerberUpdateBatchCompletion')) {
        $source = "$root/src/private/cli/$path.ps1"
        if (Test-Path $source) {
            . $source
        }
    }
    function Get-GerberUpdateItem {
        param($State)
        [pscustomobject]@{
            Kind = 'Core'; State = $State; AutoAdded = $false
        }
    }
    function Resolve-GerberUpdateBatch {
        param($CoreState, $SelectedItemList, [switch]$InspectionApproved)
        $null = $CoreState, $SelectedItemList, $InspectionApproved
    }
    function Complete-GerberUpdateBatch {
        param($Batch)
        $null = $Batch
    }
    function Resolve-GerberUpdateCredentialItemList {
        param($ItemList)
        $ItemList
    }
    function Write-GerberScreenLine {
        param($Text)
        $null = $Text
    }
    function Write-GerberPromptTrace {
        param($EventName, $Data)
        $null = $EventName, $Data
    }
    function Wait-GerberContinue {
    }
    function Show-GerberUpdateBatchRestartChoice {
        param($Text)
        $null = $Text
    }
    function Read-GerberCheckboxMenuPrompt {
        param($PromptRequest)
        $null = $PromptRequest
    }
    . "$root/src/private/cli/Read-GerberConfirmationPrompt.ps1"
    . "$root/src/private/cli/Format-GerberUpdateItemOverview.ps1"
}

Describe 'Show-GerberUpdateBatchView' -Tag 'G4A9UI' {
    BeforeEach {
        $script:core = [pscustomobject]@{
            Name = 'Gerber'; Status = 'Available'; Installed = '1.0.0'; Available = '2.0.0'; Repository = 'PSGallery'; Message = ''; Plan = $null
        }
        $pluginState = [pscustomobject]@{
            Name = 'ExamplePlugin'; Status = 'Available'; Installed = '1.0.0'; Available = '2.0.0'; Repository = 'PrivateFeed'; Message = ''; Plan = $null
        }
        $script:plugin = [pscustomobject]@{
            Kind = 'Plugin'; State = $pluginState; AutoAdded = $false; MinimumCore = $null
        }
        $script:batch = [pscustomobject]@{
            Items = @($script:plugin); InstalledCoreVersion = '1.0.0'
        }
        Mock Resolve-GerberUpdateBatch {
            $script:batch
        }
        Mock Read-GerberCheckboxMenuPrompt {
            [pscustomobject]@{
                SelectedValueList = @($script:plugin)
            }
        }
        Mock Read-GerberConfirmationPrompt {
            $false
        }
        Mock Complete-GerberUpdateBatch {
            @()
        }
        Mock Write-GerberScreenLine {
        }
        Mock Write-GerberPromptTrace {
        }
        Mock Wait-GerberContinue {
        }
    }

    It 'renders all rows without selection, credentials, inspection or installation in noninteractive mode' {
        Show-GerberUpdateBatchView -CoreState $script:core -PluginItemList @($script:plugin) -Interactive $false
        Should -Invoke Write-GerberScreenLine -ParameterFilter {
            $Text -match 'ExamplePlugin'
        }
        Should -Invoke Read-GerberCheckboxMenuPrompt -Times 0
        Should -Invoke Resolve-GerberUpdateBatch -Times 0
        Should -Invoke Complete-GerberUpdateBatch -Times 0
        Should -Invoke Wait-GerberContinue -Times 0
    }

    It 'selects only available rows using the shared unchecked checkbox and cancels installation by default' {
        $script:core.Status = 'UpToDate'
        Show-GerberUpdateBatchView -CoreState $script:core -PluginItemList @($script:plugin) -Interactive $true
        Should -Invoke Read-GerberCheckboxMenuPrompt -Times 1 -ParameterFilter {
            $PromptRequest.ItemList.Count -eq 1 -and -not $PromptRequest.ItemList[0].IsSelected -and $PromptRequest.AllowEmptySelection
        }
        Should -Invoke Read-GerberConfirmationPrompt -Times 1 -ParameterFilter {
            $PromptOptionSet.DefaultOption -eq 'cancel'
        }
        Should -Invoke Complete-GerberUpdateBatch -Times 0
        Should -Invoke Write-GerberScreenLine -ParameterFilter {
            $Text -match 'cancelled.*Nothing was installed'
        }
    }

    It 'passes exact selected item identity to resolution and the exact batch to execution after consent' {
        Mock Read-GerberConfirmationPrompt {
            $true
        }
        Show-GerberUpdateBatchView -CoreState $script:core -PluginItemList @($script:plugin) -Interactive $true
        Should -Invoke Resolve-GerberUpdateBatch -Times 1 -ParameterFilter {
            [object]::ReferenceEquals($SelectedItemList[0], $script:plugin) -and -not $InspectionApproved
        }
        Should -Invoke Complete-GerberUpdateBatch -Times 1 -ParameterFilter {
            [object]::ReferenceEquals($Batch, $script:batch)
        }
    }

    It 'preserves checkbox Escape back without inspection or installation' {
        Mock Read-GerberCheckboxMenuPrompt {
            throw [OperationCanceledException]::new('Esc')
        }
        {
            Show-GerberUpdateBatchView -CoreState $script:core -PluginItemList @($script:plugin) -Interactive $true
        } | Should -Throw '*Esc*'
        Should -Invoke Resolve-GerberUpdateBatch -Times 0
        Should -Invoke Complete-GerberUpdateBatch -Times 0
    }

    It 'allows empty selection to return without inspection or installation' {
        Mock Read-GerberCheckboxMenuPrompt {
            [pscustomobject]@{
                SelectedValueList = @()
            }
        }
        Show-GerberUpdateBatchView -CoreState $script:core -PluginItemList @($script:plugin) -Interactive $true
        Should -Invoke Resolve-GerberUpdateBatch -Times 0
        Should -Invoke Complete-GerberUpdateBatch -Times 0
        Should -Invoke Wait-GerberContinue -Times 1
    }

    It 'does not inspect or install when separate package inspection consent is declined' {
        $script:plugin.State.Plan = [pscustomobject]@{
            RequiresRepositoryTrust = $true; RequiresLicenseAcceptance = $true; RepositoryUri = 'https://example.test/v2'
        }
        Show-GerberUpdateBatchView -CoreState $script:core -PluginItemList @($script:plugin) -Interactive $true
        Should -Invoke Read-GerberConfirmationPrompt -Times 1 -ParameterFilter {
            $Prompt -eq 'Allow package inspection?'
        }
        Should -Invoke Resolve-GerberUpdateBatch -Times 0
        Should -Invoke Complete-GerberUpdateBatch -Times 0
    }

    It 'inspects with approved flags only after consent then separately confirms installation' {
        $script:plugin.State.Plan = [pscustomobject]@{
            RequiresRepositoryTrust = $true; RequiresLicenseAcceptance = $true; RepositoryUri = 'https://example.test/v2'; Scope = 'CurrentUser'
        }
        Mock Read-GerberConfirmationPrompt {
            $true
        }
        Show-GerberUpdateBatchView -CoreState $script:core -PluginItemList @($script:plugin) -Interactive $true
        Should -Invoke Resolve-GerberUpdateBatch -Times 1 -ParameterFilter {
            $InspectionApproved
        }
        Should -Invoke Read-GerberConfirmationPrompt -Times 1 -ParameterFilter {
            $Prompt -eq 'Allow package inspection?'
        }
        Should -Invoke Read-GerberConfirmationPrompt -Times 1 -ParameterFilter {
            $Prompt -eq 'Install selected updates?'
        }
    }
}
