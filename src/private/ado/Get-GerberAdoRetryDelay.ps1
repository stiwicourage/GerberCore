function Get-GerberAdoRetryDelay {
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, 10)]
        [int]$AttemptNumber
    )

    return $AttemptNumber
}
