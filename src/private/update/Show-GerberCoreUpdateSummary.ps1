function Show-GerberCoreUpdateSummary {
    param([object]$State)
    Write-GerberScreenLine -Text (Format-GerberCoreUpdateOverview $State)
    Write-GerberScreenLine -Text $State.Message
}
