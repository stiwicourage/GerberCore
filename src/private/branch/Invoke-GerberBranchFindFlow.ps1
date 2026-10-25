function Invoke-GerberBranchFindFlow {
    [CmdletBinding()]
    param()

    while ($true) {
        Show-GerberBranchFindHeader
        $rawPath = Read-GerberBranchPathInputOrNull
        if ($null -eq $rawPath) { return }

        $normalizedPath = ConvertTo-GerberNormalizedBranchPath -BranchPath $rawPath
        $result = Invoke-GerberBranchSearch -NormalizedBranchPath $normalizedPath
        Show-GerberBranchFindResult -Result $result
        if (-not (Wait-GerberBranchFindContinue)) { return }
    }
}

function Show-GerberBranchFindHeader {
    [CmdletBinding()]
    param()

    Start-GerberScreen -Name '/branch find'
    Write-GerberScreenLine -Text '/branch find'
    Write-GerberScreenLine
}

function Read-GerberBranchPathInputOrNull {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    try {
        return Read-GerberCommand -Prompt 'Branch path' -SuggestionMode 'None'
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) {
            return $null
        }
        throw
    }
}

function ConvertTo-GerberNormalizedBranchPath {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BranchPath
    )

    $trimmed = $BranchPath.Trim().TrimStart('/')
    $prefix = 'refs/heads/'
    if ($trimmed.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $trimmed
    }
    return "$prefix$trimmed"
}

function Invoke-GerberBranchSearch {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$NormalizedBranchPath
    )

    $configuration = Get-GerberAdoConfiguration
    $pat = Resolve-GerberAdoPat -Configuration $configuration
    $Host.UI.Write('Scanning repositories... ')
    return Get-GerberAdoBranchSearchResult `
        -Configuration $configuration `
        -Pat $pat `
        -NormalizedBranchPath $NormalizedBranchPath
}

function Show-GerberBranchFindResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Result
    )

    Start-GerberScreen -Name '/branch find'
    Write-GerberScreenLine -Text '/branch find'
    Write-GerberScreenLine
    Write-GerberBranchMatchResult -Result $Result
    if ($Result.FailedList.Count -gt 0) {
        Write-GerberBranchFailedWarning -FailedList $Result.FailedList
    }
}

function Write-GerberBranchMatchResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Result
    )

    if ($Result.FoundList.Count -eq 0) {
        Write-GerberScreenLine -Text "No repositories contain branch '$($Result.NormalizedBranchPath)'."
        return
    }
    foreach ($name in $Result.FoundList) {
        Write-GerberScreenLine -Text "  [+] $name"
    }
    Write-GerberScreenLine
    Write-GerberScreenLine -Text "Found in $($Result.FoundList.Count) of $($Result.Total) repositories."
}

function Write-GerberBranchFailedWarning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$FailedList
    )

    Write-GerberScreenLine
    Write-GerberScreenLine -Text "Warning: could not check $($FailedList.Count) repositories:"
    foreach ($name in $FailedList) {
        Write-GerberScreenLine -Text "  [!] $name"
    }
}

function Wait-GerberBranchFindContinue {
    [OutputType([bool])]
    [CmdletBinding()]
    param()

    try {
        Wait-GerberContinue
        return $true
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) {
            return $false
        }
        throw
    }
}
