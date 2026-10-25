function Get-GerberConnectionStringReviewScope {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Content
    )

    return [pscustomobject]@{
        ReviewedFileList = @(
            [pscustomobject]@{
                Path = $Path
                Content = $Content
            }
        )
    }
}

function Get-GerberConnectionStringReviewConfiguration {
    param(
        [Parameter(Mandatory)]
        [object[]]$ConnectionStringRuleList,

        [string]$DefaultAppSettingsEnvironmentName
    )

    $configuration = [pscustomobject]@{
        ConnectionStringRuleList = @($ConnectionStringRuleList)
    }

    if ($PSBoundParameters.ContainsKey('DefaultAppSettingsEnvironmentName')) {
        $configuration | Add-Member -MemberType NoteProperty -Name DefaultAppSettingsEnvironmentName -Value $DefaultAppSettingsEnvironmentName
    }

    return $configuration
}
