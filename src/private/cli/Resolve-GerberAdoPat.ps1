function Resolve-GerberAdoPat {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [string]$CommandLabel = 'the requested Azure DevOps operation'
    )

    if ($Configuration.PSObject.Properties.Match('ProfileName').Count -gt 0 -and
        -not [string]::IsNullOrWhiteSpace([string]$Configuration.ProfileName)) {
        return (Resolve-GerberAdoConnectionReadiness `
                -ProfileName ([string]$Configuration.ProfileName) `
                -RequireAuthentication `
                -CommandLabel $CommandLabel).Pat
    }

    $pat = Get-GerberCredential -Identifier $Configuration.CredentialIdentifier
    if (-not [string]::IsNullOrWhiteSpace($pat)) {
        return $pat
    }

    throw [System.ArgumentException]::new(
        "Gerber could not continue $CommandLabel because credential '$($Configuration.CredentialIdentifier)' has no stored PAT. Store it with /secrets set, then try again."
    )
}
