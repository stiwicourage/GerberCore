function Get-GerberPipelineReleaseContext {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandLabel
    )

    $configuration = Get-GerberAdoConfiguration
    $pat = Resolve-GerberAdoPat -Configuration $configuration -CommandLabel $CommandLabel
    return [pscustomobject]@{
        Configuration                = $configuration
        Pat                          = $pat
        FeedList                     = $null
        PendingApprovalList          = @()
        ApprovedDefinitionMismatchList = [System.Collections.Generic.List[string]]::new()
    }
}
