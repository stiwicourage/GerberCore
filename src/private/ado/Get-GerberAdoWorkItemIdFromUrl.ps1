function Get-GerberAdoWorkItemIdFromUrl {
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$WorkItemUrl
    )

    $match = [regex]::Match($WorkItemUrl, '(?i)/_workitems/edit/(?<id>\d+)')
    if (-not $match.Success) {
        throw [System.ArgumentException]::new(
            "Gerber could not read an Azure DevOps work item ID from '$WorkItemUrl'."
        )
    }

    return [int]$match.Groups['id'].Value
}
