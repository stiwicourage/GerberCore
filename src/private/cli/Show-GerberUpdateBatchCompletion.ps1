function Show-GerberUpdateBatchCompletion {
    param([object[]]$ResultList)
    Write-GerberUpdateBatchResultList -ResultList $ResultList
    $restart = @($ResultList | Where-Object {
        $_.Outcome -in @('Installed', 'AlreadyInstalled') -and $_.VerificationStatus -eq 'Verified' -and $_.RestartRequired
    })
    if ($restart.Count -gt 0) {
        return Show-GerberUpdateBatchRestartChoice -Text (Get-GerberUpdateBatchRestartText -ResultList $ResultList)
    }
    Wait-GerberContinue
}

function Write-GerberUpdateBatchResultList {
    param([object[]]$ResultList)
    foreach ($result in $ResultList) {
        Write-GerberScreenLine -Text (Format-GerberUpdateBatchResultLine -Result $result)
        Write-GerberPromptTrace -EventName 'update-install-complete' -Data @{
            Component = $result.Item.State.Name; Outcome = $result.Outcome; Activation = $result.ActivationStatus
        }
    }
}

function Get-GerberUpdateBatchRestartText {
    param([object[]]$ResultList)
    $summary = @($ResultList | ForEach-Object {
        Format-GerberUpdateBatchResultLine -Result $_
    }) -join "`n"
    "$summary`n`nRestart PowerShell, then run gerber. Installed components are not hot reloaded in this session."
}

function Format-GerberUpdateBatchResultLine {
    param([object]$Result)
    $symbol = Get-GerberUpdateBatchResultSymbol -Outcome $Result.Outcome
    $label = if ($Result.Outcome -eq 'AlreadyInstalled') { 'already installed' } else { $Result.Outcome.ToLowerInvariant() }
    $lines = @("$symbol $($Result.Item.State.Name)  $label")
    $installed = $Result.Outcome -in @('Installed', 'AlreadyInstalled')
    if (-not $installed -and $Result.Message) {
        $lines += "    $($Result.Message)"
    }
    $detail = Get-GerberUpdateBatchResultDetail -Result $Result
    if ($detail) {
        $lines += "    $detail"
    }
    $lines -join "`
"
}

function Get-GerberUpdateBatchResultSymbol {
    param([string]$Outcome)
    switch ($Outcome) {
        { $_ -in @('Installed', 'AlreadyInstalled') } { '✔' }
        { $_ -in @('Cancelled', 'NotAttempted') } { '-' }
        default { '✖' }
    }
}

function Get-GerberUpdateBatchResultDetail {
    param([object]$Result)
    if ((Test-GerberUpdateBatchResultClean -Result $Result) -or (Test-GerberUpdateBatchResultUntouched -Result $Result)) {
        return
    }
    "Verification: $($Result.VerificationStatus) · Recovery: $($Result.RecoveryStatus) · Activation: $($Result.ActivationStatus)"
}

function Test-GerberUpdateBatchResultClean {
    param([object]$Result)
    if ($Result.Outcome -notin @('Installed', 'AlreadyInstalled')) {
        return $false
    }
    $Result.VerificationStatus -eq 'Verified' -and $Result.RecoveryStatus -eq 'NotRequired' -and $Result.ActivationStatus -ne 'Failed'
}

function Test-GerberUpdateBatchResultUntouched {
    param([object]$Result)
    $Result.VerificationStatus -eq 'NotRun' -and $Result.RecoveryStatus -eq 'NotRequired' -and $Result.ActivationStatus -eq 'NotRun'
}
