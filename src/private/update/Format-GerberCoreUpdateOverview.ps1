function Format-GerberCoreUpdateOverview {
    param([object]$State)
    $row = [pscustomobject][ordered]@{
        Component = 'Core'; Name = $State.Name; Installed = $State.Installed
        Available = $State.Available; Repository = $State.Repository; Status = $State.Status
    }
    ($row | Format-Table -AutoSize | Out-String).Trim()
}
