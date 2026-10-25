function Show-GerberPipelineReleaseLoadingScreen {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory)]
        [string]$CommandLabel
    )

    Show-GerberPipelineReleaseHeader -CommandLabel $CommandLabel
    Write-GerberScreenLine -Text $Text
}

function Show-GerberPipelineReleaseHeader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandLabel
    )

    Start-GerberScreen -Name $CommandLabel
    Write-GerberScreenLine -Text $CommandLabel
    Write-GerberScreenLine
}
