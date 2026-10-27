# Loaded only into the disposable PTY Gerber module instance. Never calls a real provider.
$script:GerberTerminalUpdateStartup = $false
function script:Get-GerberTerminalUpdateFixture {
    param()
    if (-not (Test-Path -LiteralPath $script:GerberTerminalUpdateFixturePath)) {
        return @{ disposition = 'UpToDate'; startupStatus = 'Unavailable' }
    }
    Get-Content -LiteralPath $script:GerberTerminalUpdateFixturePath -Raw | ConvertFrom-Json -AsHashtable
}

function script:Get-GerberTerminalUpdateState {
    param()
    $path = Join-Path (Split-Path $script:GerberTerminalUpdateFixturePath -Parent) 'update-state.json'
    if (-not (Test-Path -LiteralPath $path)) { return @{ discoveryCount = 0; startupDiscoveryCount = 0; installCount = 0 } }
    Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
}

function script:Get-GerberTerminalUpdateErrorMessage {
    param([hashtable]$Fixture)
    if ($Fixture.Contains('installErrorMessage')) { return $Fixture.installErrorMessage }
    'raw-update-token'
}

function script:Write-GerberTerminalUpdateState {
    param([hashtable]$State)
    $path = Join-Path (Split-Path $script:GerberTerminalUpdateFixturePath -Parent) 'update-state.json'
    [IO.File]::WriteAllText($path, ($State | ConvertTo-Json))
}

function script:Invoke-GerberUpdateProbe {
    param([object]$Request, [int]$TimeoutMilliseconds)
    if ($TimeoutMilliseconds -ne 2000) { throw 'Unexpected startup budget.' }
    $script:GerberTerminalUpdateStartup = $true
    try {
        Get-GerberCoreUpdateState -Request $Request | Select-Object Status, Name, Installed, Available, Repository, Message
    } finally { $script:GerberTerminalUpdateStartup = $false }
}

function script:Get-PSModuleUpdate {
    [CmdletBinding()]
    param([object]$Module, [string]$Repository, [hashtable]$Policy, [pscredential]$Credential)
    Assert-GerberTerminalUpdateRequest $Module $Repository $Policy $Credential
    $fixture = Get-GerberTerminalUpdateFixture
    $state = Get-GerberTerminalUpdateState
    if ($script:GerberTerminalUpdateStartup) { $state.startupDiscoveryCount++ } else { $state.discoveryCount++ }
    $state.repository = $Repository
    $state.channel = $Policy.Channel
    if ($script:GerberTerminalUpdateStartup) { $state.startupChannel = $Policy.Channel }
    Write-GerberTerminalUpdateState $state
    Assert-GerberTerminalUpdateDiscovery $fixture $state
    $script:GerberTerminalLiveUpdatePlan = Get-GerberTerminalUpdatePlan $fixture $Policy.Channel
    $script:GerberTerminalLiveUpdatePlan
}

function script:Assert-GerberTerminalUpdateDiscovery {
    param([hashtable]$Fixture, [hashtable]$State)
    if ($Fixture.Contains('noMatchingPackage')) { Write-Error -ErrorId 'PMU.PackageNotFound' -Message 'No eligible fixture package' -ErrorAction Stop }
    if ($Fixture.Contains('discoveryError')) { Write-Error -ErrorId $Fixture.discoveryError -Message 'raw-update-token' -ErrorAction Stop }
    if (Test-GerberTerminalUpdateFailure $Fixture $State) { throw 'raw-update-token in provider failure' }
}

function script:Test-GerberTerminalUpdateFailure {
    param([hashtable]$Fixture, [hashtable]$State)
    if ($script:GerberTerminalUpdateStartup) { return $Fixture.startupStatus -eq 'Unavailable' }
    if (-not $Fixture.Contains('failDiscoveryCount')) { return $false }
    $State.discoveryCount -le $Fixture.failDiscoveryCount
}

function script:Assert-GerberTerminalUpdateRequest {
    param([object]$Module, [string]$Repository, [hashtable]$Policy, [pscredential]$Credential)
    if ($Module.Name -ne 'Gerber' -or $Repository -cne 'PSGallery') { throw 'Unexpected terminal update target.' }
    if ($Policy.Channel -cnotin @('Stable', 'IncludePrerelease') -or $Policy.Scope -cne 'CurrentUser') { throw 'Unexpected terminal update policy.' }
    if ($Policy.ExpectedRepositoryUri.AbsoluteUri -cne 'https://www.powershellgallery.com/api/v2') { throw 'Unexpected terminal update endpoint.' }
    if ($null -ne $Credential) { throw 'Core must not request credentials.' }
}

function script:Get-GerberTerminalUpdatePlan {
    param([hashtable]$Fixture, [string]$Channel)
    $installed = if ($Fixture.Contains('installedVersion')) { $Fixture.installedVersion } else { '0.1.0-preview' }
    $target = if ($Fixture.Contains('targetVersion')) { $Fixture.targetVersion } else { '0.2.0' }
    [pscustomobject]@{
        ModuleName = 'Gerber'; InstalledVersion = $installed; TargetVersion = $target
        RepositoryName = 'PSGallery'; UpdateAvailable = $Fixture.disposition -eq 'UpdateAvailable'
        RepositoryUri = 'https://www.powershellgallery.com/api/v2'; Channel = $Channel; Scope = 'CurrentUser'
        Disposition = $Fixture.disposition; RestartRequired = $false
        RequiresRepositoryTrust = $false; RequiresLicenseAcceptance = $false
    }

    $script:GerberTerminalSaveConfiguration = ${function:Save-GerberUserConfiguration}
    function script:Save-GerberUserConfiguration {
        [CmdletBinding(SupportsShouldProcess)]
        param([object]$Configuration)
        if (-not $PSCmdlet.ShouldProcess('disposable terminal configuration', 'Save')) { return }
        $fixture = Get-GerberTerminalUpdateFixture
        if ($fixture.Contains('failPolicySaveCount') -and $fixture.failPolicySaveCount -gt 0) {
            $fixture.failPolicySaveCount--
            [IO.File]::WriteAllText($script:GerberTerminalUpdateFixturePath, ($fixture | ConvertTo-Json))
            throw [IO.IOException]::new('Simulated configuration write failure.')
        }
        & $script:GerberTerminalSaveConfiguration -Configuration $Configuration -Confirm:$false
    }
}

function script:Install-PSModuleUpdate {
    [CmdletBinding(SupportsShouldProcess)]
    param([object]$Update, [pscredential]$Credential, [switch]$TrustRepository, [switch]$AcceptLicense)
    $null = $Credential, $TrustRepository, $AcceptLicense
    if (-not [object]::ReferenceEquals($Update, $script:GerberTerminalLiveUpdatePlan)) { throw 'A stale terminal plan was supplied.' }
    if (-not $PSCmdlet.ShouldProcess('disposable terminal fixture', 'Record simulated installation')) { return }
    $state = Get-GerberTerminalUpdateState
    $state.installCount++
    Write-GerberTerminalUpdateState $state
    $fixture = Get-GerberTerminalUpdateFixture
    if ($fixture.Contains('installError')) {
        Write-Error -ErrorId $fixture.installError -Message (Get-GerberTerminalUpdateErrorMessage $fixture) -ErrorAction Stop
    }
    [pscustomobject]@{ Outcome = 'Installed'; VerificationStatus = 'Verified'; RecoveryStatus = 'NotRequired'; RestartRequired = $true }
}
