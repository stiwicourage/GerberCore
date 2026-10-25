function Get-GerberAdoCredentialIdentifier {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProfileName
    )

    return Get-GerberCredentialIdentifier -Scope 'ado' -SegmentList @($ProfileName, 'pat')
}
