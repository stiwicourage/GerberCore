function Get-GerberBoundaryDiagnostic {
    param($Document, $Extent, [hashtable]$Finding)

    return [pscustomobject][ordered]@{
        File = $Document.File
        Line = $Extent.StartLineNumber
        Column = $Extent.StartColumnNumber
        Dependency = $Finding.Dependency
        Reason = $Finding.Reason
        Resolution = $Finding.Resolution
    }
}
