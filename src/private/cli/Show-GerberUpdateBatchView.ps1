function Show-GerberUpdateBatchView {
    param([object]$CoreState, [object[]]$PluginItemList, [bool]$Interactive)
    $items = @((Get-GerberUpdateItem -State $CoreState)) + $PluginItemList
    Write-GerberUpdateBatchOverview -ItemList $items
    if ($Interactive) {
        Show-GerberInteractiveUpdateBatch -CoreState $CoreState -ItemList $items
    }
}

function Show-GerberInteractiveUpdateBatch {
    param([object]$CoreState, [object[]]$ItemList)
    $readyItems = @(Resolve-GerberUpdateCredentialItemList -ItemList $ItemList)
    $selected = @(Read-GerberUpdateItemSelection -ItemList $readyItems)
    if ($selected.Count -eq 0) {
        return Show-GerberUpdateBatchCancellation
    }
    $batch = Get-GerberConfirmedUpdateBatch -CoreState $CoreState -SelectedItemList $selected
    if ($null -eq $batch) {
        return Show-GerberUpdateBatchCancellation
    }
    Write-GerberScreenLine -Text 'Installing selected updates sequentially...'
    $results = @(Complete-GerberUpdateBatch -Batch $batch)
    Show-GerberUpdateBatchCompletion -ResultList $results
}

function Write-GerberUpdateBatchOverview {
    param([object[]]$ItemList)
    foreach ($item in $ItemList) {
        Write-GerberScreenLine -Text (Format-GerberUpdateItemOverview -Item $item)
    }
    Write-GerberPromptTrace -EventName 'update-discovery' -Data @{
        ComponentCount = $ItemList.Count
    }
}

function Get-GerberConfirmedUpdateBatch {
    param([object]$CoreState, [object[]]$SelectedItemList)
    $approval = Read-GerberUpdateInspectionConsent -SelectedItemList $SelectedItemList
    if ($false -eq $approval) {
        return
    }
    $batch = Resolve-GerberUpdateBatch -CoreState $CoreState -SelectedItemList $SelectedItemList -InspectionApproved:($true -eq $approval)
    if (Read-GerberUpdateBatchInstallConsent -Batch $batch) {
        $batch
    }
}

function Read-GerberUpdateBatchInstallConsent {
    param([object]$Batch)
    $text = Get-GerberUpdateBatchConsentText -Batch $Batch
    $options = Get-GerberConfirmationPromptOptionSet -ActionLabel 'Install selected updates' -CancelLabel 'Cancel' -DefaultOption 'cancel'
    $accepted = Read-GerberConfirmationPrompt -Prompt 'Install selected updates?' -ScreenTitle '/update list' -ScreenText $text -PromptOptionSet $options
    Write-GerberPromptTrace -EventName 'update-confirmation' -Data @{
        Accepted = $accepted; ComponentCount = @($Batch.Items).Count
    }
    $accepted
}

function Show-GerberUpdateBatchCancellation {
    param()
    Write-GerberScreenLine -Text 'Update selection cancelled. Nothing was installed.'
    Wait-GerberContinue
}
