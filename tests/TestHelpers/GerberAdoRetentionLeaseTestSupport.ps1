function Test-GerberRetentionLeaseQuery {
    [OutputType([bool])]
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Query)

    return $Query -match 'ownerId=Gerber\.ProdRetention' -and
        $Query -match 'definitionId=53' -and
        $Query -match 'runId=9001' -and
        $Query -match 'api-version=7\.1'
}

function Test-GerberRetentionLeaseBody {
    [OutputType([bool])]
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Body)

    return $Body -match '"daysValid"\s*:\s*36500' -and
        $Body -match '"definitionId"\s*:\s*53' -and
        $Body -match '"ownerId"\s*:\s*"Gerber\.ProdRetention"' -and
        $Body -match '"runId"\s*:\s*9001'
}
