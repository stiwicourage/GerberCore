function Resolve-GerberCredentialServiceName {
    [OutputType([string])]
    [CmdletBinding()]
    param([bool]$Windows = $IsWindows)

    if ($Windows) {
        return 'gerber://credentials'
    }

    return 'credentials'
}
