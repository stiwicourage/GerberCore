function Resolve-GerberCoreUpdateRequest {
    param()
    $module = (Get-Command Invoke-Gerber -CommandType Function -ErrorAction Stop).Module
    if ($null -eq $module) {
        throw [System.InvalidOperationException]::new('The executing Gerber module could not be identified. Import Gerber before checking updates.')
    }
    [pscustomobject]@{ Module = $module }
}
