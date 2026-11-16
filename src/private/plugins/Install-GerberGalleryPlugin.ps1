function Install-GerberGalleryPlugin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    # The user already confirmed the installation inside Gerber, so the module-level trust prompt is skipped.
    Install-PSResource -Name $Name -Repository PSGallery -Scope CurrentUser -TrustRepository -Quiet -ErrorAction Stop
}
