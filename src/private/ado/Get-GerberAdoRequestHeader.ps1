function Get-GerberAdoRequestHeader {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Pat
    )

    $tokenBytes = [System.Text.Encoding]::UTF8.GetBytes(":$Pat")
    $tokenValue = [Convert]::ToBase64String($tokenBytes)
    return @{
        Authorization = "Basic $tokenValue"
        'User-Agent' = 'Gerber'
    }
}
