function Get-GerberUpdateBatchConsentText {
    param([object]$Batch)
    $items = @($Batch.Items)
    $width = ($items.State.Name | Measure-Object -Property Length -Maximum).Maximum
    $lines = @($items | ForEach-Object {
        Get-GerberUpdateItemConsentLine -Item $_ -Batch $Batch -NameWidth $width
    })
    $footer = Get-GerberUpdateBatchSourceText -ItemList $items
    "Will install (Core first when required):`n" + ($lines -join "`n") + "`n`n$footer`nGerber will not hot reload components or roll back the batch."
}

function Get-GerberUpdateItemConsentLine {
    param([object]$Item, [object]$Batch, [int]$NameWidth)
    $state = $Item.State
    $name = $state.Name.PadRight($NameWidth)
    if ($state.Status -ne 'Available') {
        return "  $name  $($state.Status): $($state.Message)"
    }
    $note = Get-GerberUpdateItemConsentNote -Item $Item -Batch $Batch
    "  $name  $($state.Installed) -> $($state.Available)$note"
}

function Get-GerberUpdateItemConsentNote {
    param([object]$Item, [object]$Batch)
    if ($Item.AutoAdded) {
        $requiring = @($Batch.Items | Where-Object {
            $_.Kind -eq 'Plugin' -and $_.MinimumCore
        } | ForEach-Object { $_.State.Name })
        return "  (added: required by $($requiring -join ', '))"
    }
    if ($Item.MinimumCore) {
        return "  (requires Core >= $($Item.MinimumCore))"
    }
}

function Get-GerberUpdateBatchSourceText {
    param([object[]]$ItemList)
    $plans = @($ItemList | Where-Object { $null -ne $_.State.Plan } | ForEach-Object { $_.State.Plan })
    $uris = @($plans.RepositoryUri | Select-Object -Unique) -join ', '
    $scopes = @($plans.Scope | Select-Object -Unique) -join ', '
    "Source: $uris · Scope: $scopes"
}
