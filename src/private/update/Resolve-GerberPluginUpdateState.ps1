function Resolve-GerberPluginUpdateState {
    param([object]$Entry, [pscredential]$Credential)
    $item = Get-GerberPluginUpdateItem $Entry $Credential
    try {
        Complete-GerberPluginUpdateDiscovery $item
    } catch {
        Assert-GerberUpdateNotCancelled $_
        Complete-GerberPluginUpdateFailure $item $_
    }
    $item
}

function Get-GerberPluginUpdateItem {
    param([object]$Entry, [pscredential]$Credential)
    $item = Get-GerberUpdateItem (Get-GerberPluginUpdateOverview $Entry)
    $item.Kind = 'Plugin'
    $item.Plugin = $Entry
    $item.Credential = $Credential
    $item
}

function Get-GerberPluginUpdateOverview {
    param([object]$Entry)
    [pscustomobject]@{
        Name       = $Entry.Name
        Installed  = $Entry.Version
        Available  = '-'
        Repository = '-'
        Status     = 'Unavailable'
        Plan       = $null
        Channel    = $null
        Message    = 'Check the declared plugin repository and installation, then retry /update list.'
    }
}

function Complete-GerberPluginUpdateDiscovery {
    param([object]$Item)
    $module = Read-GerberPluginUpdateModule $Item.Plugin
    $manifest = Read-GerberPluginUpdateManifest $Item.Plugin
    $uri = Resolve-GerberPluginRepositoryUri $manifest.PrivateData
    $policy = Resolve-GerberPluginUpdatePolicy $module $uri
    $Item.State.Repository = $uri.AbsoluteUri
    $Item.State.Channel = $policy.Channel
    $plan = Get-PSModuleUpdate -Module (Resolve-GerberPluginUpdateActiveModule $module) -RepositoryUri $uri -Policy $policy -Credential $Item.Credential `
        -ErrorAction Stop -WarningAction SilentlyContinue -InformationAction SilentlyContinue -Verbose:$false -Debug:$false
    Complete-GerberPluginUpdateOverview $Item.State $plan
}

function Resolve-GerberPluginUpdateActiveModule {
    param([object]$Selected)
    $loaded = @(Get-Module -Name $Selected.Name -ErrorAction Stop | Where-Object Guid -EQ $Selected.Guid)
    if ($loaded.Count -eq 0) {
        return $Selected
    }
    if ($loaded.Count -ne 1) {
        throw [InvalidOperationException]::new('The active plugin installation is ambiguous.')
    }
    $loaded[0]
}

function Read-GerberPluginUpdateModule {
    param([object]$Entry)
    $modules = @(Get-Module -ListAvailable -Name $Entry.ModulePath -ErrorAction Stop)
    if ($modules.Count -ne 1) {
        throw [System.InvalidOperationException]::new('The selected plugin installation is ambiguous or missing.')
    }
    $module = $modules[0]
    if ($module.Name -cne $Entry.Name -or $module.Guid -ne [guid]$Entry.Guid) {
        throw [System.InvalidOperationException]::new('The selected plugin identity changed.')
    }
    $module
}

function Read-GerberPluginUpdateManifest {
    param([object]$Entry)
    $manifest = Import-PowerShellDataFile -LiteralPath $Entry.ModulePath -ErrorAction Stop
    if ([guid]$manifest.GUID -ne [guid]$Entry.Guid) {
        throw [System.InvalidOperationException]::new('The selected plugin manifest identity changed.')
    }
    $manifest
}

function Resolve-GerberPluginRepositoryUri {
    param([object]$PrivateData)
    $metadata = Read-GerberPluginUpdateMetadataRecord $PrivateData
    if (-not $metadata.Contains('RepositoryUri')) {
        return [uri]'https://www.powershellgallery.com/api/v2'
    }
    $uri = $null
    if (-not [uri]::TryCreate([string]$metadata.RepositoryUri, [UriKind]::Absolute, [ref]$uri)) {
        throw [System.InvalidOperationException]::new('The declared plugin repository URI is invalid.')
    }
    Assert-GerberPluginRepositoryUri $uri
    $uri
}

function Read-GerberPluginUpdateMetadataRecord {
    param([object]$PrivateData)
    $metadata = Get-GerberModulePrivateDataValueOrNull $PrivateData 'Gerber'
    if ($null -eq $metadata) {
        throw [System.InvalidOperationException]::new('Plugin metadata is missing.')
    }
    $metadata
}

function Assert-GerberPluginRepositoryUri {
    param([uri]$Uri)
    foreach ($component in @($Uri.UserInfo, $Uri.Query, $Uri.Fragment)) {
        if ($component) {
            throw [System.InvalidOperationException]::new('The declared repository URI must not contain credentials, query or fragment.')
        }
    }
}

function Resolve-GerberPluginUpdatePolicy {
    param([object]$Module, [uri]$RepositoryUri)
    $policy = Resolve-GerberCoreUpdatePolicy
    $policy.Scope = Resolve-GerberPluginUpdateScope $Module
    $policy.ExpectedRepositoryUri = $RepositoryUri
    $policy
}

function Complete-GerberPluginUpdateOverview {
    param([object]$State, [object]$Plan)
    $State.Plan = $Plan
    $State.Installed = $Plan.InstalledVersion
    $State.Available = $Plan.TargetVersion
    $State.Status = Resolve-GerberUpdateDisposition $Plan
    $State.Message = "Plugin update status: $($State.Status)."
}

function Complete-GerberPluginUpdateFailure {
    param([object]$Item, [System.Management.Automation.ErrorRecord]$ErrorRecord)
    $statuses = @{
        'PMU.PackageNotFound'      = 'NoMatchingPackage'
        'PMU.AuthenticationFailed' = 'CredentialRequired'
    }
    $id = ($ErrorRecord.FullyQualifiedErrorId -split ',')[0]
    $Item.State.Status = $statuses[$id] ?? 'Unavailable'
    $Item.State.Plan = $null
}
