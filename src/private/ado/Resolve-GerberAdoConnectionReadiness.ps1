function Resolve-GerberAdoConnectionReadiness {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [string]$ProfileName,

        [switch]$RequireAuthentication,

        [string]$CommandLabel = 'the requested Azure DevOps operation'
    )

    $selectionParameters = @{
        CommandLabel          = $CommandLabel
        RequireAuthentication = $RequireAuthentication
    }
    if ($PSBoundParameters.ContainsKey('ProfileName')) {
        $selectionParameters.ProfileName = $ProfileName
    }

    $selection = Resolve-GerberAdoConnectionSelection @selectionParameters
    $connectionProfile = Resolve-GerberAdoConnectionProfile -Name $selection.ProfileName
    $credentialIdentifier = Get-GerberAdoCredentialIdentifier -ProfileName $connectionProfile.ProfileName

    $pat = $null
    if ($RequireAuthentication) {
        $pat = Resolve-GerberAdoConnectionPat `
            -ConnectionProfile $connectionProfile `
            -PatIdentifier $credentialIdentifier `
            -CommandLabel $CommandLabel
    }

    return [pscustomobject][ordered]@{
        ConnectionProfile    = $connectionProfile
        CredentialIdentifier = $credentialIdentifier
        Pat                  = $pat
    }
}

function Resolve-GerberAdoConnectionSelection {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$ProfileName,

        [Parameter(Mandatory)]
        [string]$CommandLabel,

        [Parameter(Mandatory)]
        [bool]$RequireAuthentication
    )

    $configuration = Get-GerberUserConfiguration
    $profileList = @(Get-GerberAdoConnectionProfile -Configuration $configuration)

    if ($PSBoundParameters.ContainsKey('ProfileName')) {
        return Resolve-GerberExplicitAdoConnectionSelection `
            -Configuration $configuration `
            -ProfileName $ProfileName `
            -CommandLabel $CommandLabel `
            -RequireAuthentication:$RequireAuthentication
    }

    $defaultProfile = Get-GerberDefaultAdoConnectionProfile -Configuration $configuration
    if ($null -ne $defaultProfile) {
        return Get-GerberResolvedAdoSelection -ProfileName $defaultProfile.Name
    }

    $sessionConnectionProfile = Get-GerberSessionAdoProfile -Configuration $configuration
    if ($null -ne $sessionConnectionProfile) {
        return Get-GerberResolvedAdoSelection -ProfileName $sessionConnectionProfile.Name
    }

    if ($profileList.Count -eq 0) {
        Assert-GerberAdoInteractiveSetupAvailable -CommandLabel $CommandLabel -Reason 'no Azure DevOps connection is configured'
        return Resolve-GerberAdoCreatedConnectionSelection `
            -Configuration $configuration `
            -CommandLabel $CommandLabel `
            -RequireAuthentication:$RequireAuthentication
    }

    if ($profileList.Count -eq 1) {
        Assert-GerberAdoInteractiveSetupAvailable -CommandLabel $CommandLabel -Reason 'no default Azure DevOps profile is configured'
        return Resolve-GerberSingleAdoConnectionSelection `
            -Configuration $configuration `
            -ConnectionProfile $profileList[0] `
            -CommandLabel $CommandLabel
    }

    Assert-GerberAdoInteractiveSetupAvailable -CommandLabel $CommandLabel -Reason 'no default Azure DevOps profile is configured'
    return Resolve-GerberSelectedAdoConnectionSelection `
        -Configuration $configuration `
        -ProfileList $profileList `
        -CommandLabel $CommandLabel
}

function Resolve-GerberExplicitAdoConnectionSelection {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Configuration,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$ProfileName,

        [Parameter(Mandatory)]
        [string]$CommandLabel,

        [Parameter(Mandatory)]
        [bool]$RequireAuthentication
    )

    $existingProfile = Get-GerberAdoConnectionProfile -Name $ProfileName -Configuration $Configuration
    if ($null -ne $existingProfile) {
        return Get-GerberResolvedAdoSelection -ProfileName $existingProfile.Name
    }

    Assert-GerberAdoInteractiveSetupAvailable `
        -CommandLabel $CommandLabel `
        -Reason "Azure DevOps profile '$ProfileName' is not configured"

    $screenText = @(
        "Azure DevOps profile '$ProfileName' is not configured."
        ''
        'Would you like to configure it now?'
    ) -join [Environment]::NewLine
    if (-not (Read-GerberAdoSetupConfirmation `
            -CommandLabel $CommandLabel `
            -ScreenText $screenText `
            -Prompt 'Configure missing profile')) {
        throw (Get-GerberMenuEscapeException)
    }

    $setupRequest = Get-GerberAdoConnectionSetupRequest `
        -ProfileName $ProfileName `
        -ProfileNameIsFixed:$true `
        -RequireAuthentication:$RequireAuthentication
    $createdProfile = Invoke-GerberAdoConnectionSetup `
        -Configuration $Configuration `
        -CommandLabel $CommandLabel `
        -SetupRequest $setupRequest
    return Get-GerberResolvedAdoSelection -ProfileName $createdProfile.Name
}

function Resolve-GerberAdoCreatedConnectionSelection {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Configuration,

        [Parameter(Mandatory)]
        [string]$CommandLabel,

        [Parameter(Mandatory)]
        [bool]$RequireAuthentication
    )

    $screenText = @(
        'No Azure DevOps connection has been configured.'
        ''
        'Would you like to configure one now?'
    ) -join [Environment]::NewLine
    if (-not (Read-GerberAdoSetupConfirmation `
            -CommandLabel $CommandLabel `
            -ScreenText $screenText `
            -Prompt 'Configure Azure DevOps connection')) {
        throw (Get-GerberMenuEscapeException)
    }

    $setupRequest = Get-GerberAdoConnectionSetupRequest -RequireAuthentication:$RequireAuthentication
    $createdProfile = Invoke-GerberAdoConnectionSetup `
        -Configuration $Configuration `
        -CommandLabel $CommandLabel `
        -SetupRequest $setupRequest
    return Get-GerberResolvedAdoSelection -ProfileName $createdProfile.Name
}

function Resolve-GerberSingleAdoConnectionSelection {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Configuration,

        [Parameter(Mandatory)]
        [pscustomobject]$ConnectionProfile,

        [Parameter(Mandatory)]
        [string]$CommandLabel
    )

    $screenText = @(
        "Gerber found one Azure DevOps connection profile: '$($ConnectionProfile.Name)'."
        "Project: $($ConnectionProfile.ProjectUrl)"
        ''
        'Would you like to use it now?'
    ) -join [Environment]::NewLine
    if (-not (Read-GerberAdoSetupConfirmation `
            -CommandLabel $CommandLabel `
            -ScreenText $screenText `
            -Prompt 'Use existing connection')) {
        throw (Get-GerberMenuEscapeException)
    }

    Complete-GerberAdoDefaultProfileChoice `
        -Configuration $Configuration `
        -ConnectionProfile $ConnectionProfile `
        -CommandLabel $CommandLabel
    return Get-GerberResolvedAdoSelection -ProfileName $ConnectionProfile.Name
}

function Resolve-GerberSelectedAdoConnectionSelection {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Configuration,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$ProfileList,

        [Parameter(Mandatory)]
        [string]$CommandLabel
    )

    $selectedProfile = Read-GerberAdoExistingConnectionProfile `
        -CommandLabel $CommandLabel `
        -ProfileList $ProfileList
    Complete-GerberAdoDefaultProfileChoice `
        -Configuration $Configuration `
        -ConnectionProfile $selectedProfile `
        -CommandLabel $CommandLabel
    return Get-GerberResolvedAdoSelection -ProfileName $selectedProfile.Name
}

function Complete-GerberAdoDefaultProfileChoice {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Configuration,

        [Parameter(Mandatory)]
        [pscustomobject]$ConnectionProfile,

        [Parameter(Mandatory)]
        [string]$CommandLabel
    )

    $screenText = @(
        "Connection name: $($ConnectionProfile.Name)"
        "Project: $($ConnectionProfile.ProjectUrl)"
        ''
        'Set this as the default connection?'
    ) -join [Environment]::NewLine
    if (-not (Read-GerberAdoSetupConfirmation `
            -CommandLabel $CommandLabel `
            -ScreenText $screenText `
            -Prompt 'Set default connection')) {
        return
    }

    Save-GerberSelectedAdoDefaultProfile -Configuration $Configuration -ProfileName $ConnectionProfile.Name
}

function Save-GerberSelectedAdoDefaultProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Configuration,

        [Parameter(Mandatory)]
        [string]$ProfileName
    )

    $candidateConfiguration = Copy-GerberUserConfigurationMap -Configuration $Configuration
    $adoConfiguration = Get-GerberOrAddConfigurationSection -Configuration $candidateConfiguration -PropertyName 'ado'
    $adoConfiguration['defaultProfile'] = $ProfileName
    $null = Test-GerberUserConfiguration -Configuration $candidateConfiguration -Path (Resolve-GerberUserConfigPath)
    Save-GerberUserConfiguration -Configuration $candidateConfiguration
}

function Invoke-GerberAdoConnectionSetup {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Configuration,

        [Parameter(Mandatory)]
        [string]$CommandLabel,

        [Parameter(Mandatory)]
        [pscustomobject]$SetupRequest
    )

    $projectResolution = Read-GerberAdoProjectSetupResolution -CommandLabel $CommandLabel
    $existingProfileList = @(Get-GerberAdoConnectionProfile -Configuration $Configuration)
    $resolvedProfileName = if ($SetupRequest.ProfileNameIsFixed) {
        Assert-GerberAdoConnectionProfileLookupName -Name $SetupRequest.ProfileName
        $SetupRequest.ProfileName
    } else {
        Read-GerberAdoNewConnectionProfileName `
            -CommandLabel $CommandLabel `
            -ExistingProfileList $existingProfileList `
            -ProjectUri $projectResolution.ProjectUri
    }
    $setAsDefault = Read-GerberAdoSetupConfirmation `
        -CommandLabel $CommandLabel `
        -ScreenText (@(
                "Project: $($projectResolution.ProjectUri.AbsoluteUri)"
                "Connection name: $resolvedProfileName"
                ''
                'Set this as the default connection?'
            ) -join [Environment]::NewLine) `
        -Prompt 'Set default connection'

    Save-GerberAdoConnectionProfileConfig `
        -Configuration $Configuration `
        -ProfileName $resolvedProfileName `
        -ProjectResolution $projectResolution `
        -SetAsDefault:$setAsDefault

    if ($SetupRequest.RequireAuthentication) {
        try {
            $null = Save-GerberAdoConnectionPat `
                -CommandLabel $CommandLabel `
                -ProfileName $resolvedProfileName
        } catch {
            throw [System.ArgumentException]::new(
                "Gerber saved Azure DevOps connection '$resolvedProfileName' but could not store PAT credential '$((Get-GerberAdoCredentialIdentifier -ProfileName $resolvedProfileName))'. Retry the command or use /secrets set to complete setup. $($_.Exception.Message)",
                $_.Exception
            )
        }
    }

    return Get-GerberAdoConnectionProfile -Name $resolvedProfileName
}

function Get-GerberAdoConnectionSetupRequest {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [string]$ProfileName,

        [bool]$ProfileNameIsFixed = $false,

        [bool]$RequireAuthentication = $false
    )

    return [pscustomobject]@{
        ProfileName           = $ProfileName
        ProfileNameIsFixed    = $ProfileNameIsFixed
        RequireAuthentication = $RequireAuthentication
    }
}

function Read-GerberAdoProjectSetupResolution {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandLabel
    )

    while ($true) {
        $projectUrl = Read-GerberAdoSetupTextValue `
            -CommandLabel $CommandLabel `
            -Prompt 'Azure DevOps project URL'
        try {
            return Resolve-GerberAdoProjectUrl -Url $projectUrl
        } catch [System.ArgumentException] {
            if (Test-GerberAdoServerRootPromptRequired -Message $_.Exception.Message) {
                return Resolve-GerberAdoProjectUrlWithExplicitServerRoot `
                    -CommandLabel $CommandLabel `
                    -ProjectUrl $projectUrl
            }

            Show-GerberAdoSetupValidationError -CommandLabel $CommandLabel -Message $_.Exception.Message
        }
    }
}

function Resolve-GerberAdoProjectUrlWithExplicitServerRoot {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandLabel,

        [Parameter(Mandatory)]
        [string]$ProjectUrl
    )

    while ($true) {
        $serverUrl = Read-GerberAdoSetupTextValue `
            -CommandLabel $CommandLabel `
            -Prompt 'Azure DevOps Server root URL'
        try {
            return Resolve-GerberAdoProjectUrl `
                -Url $ProjectUrl `
                -DeploymentType 'Server' `
                -ServerUri ([uri]$serverUrl)
        } catch [System.ArgumentException] {
            Show-GerberAdoSetupValidationError -CommandLabel $CommandLabel -Message $_.Exception.Message
        }
    }
}

function Test-GerberAdoServerRootPromptRequired {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    return $Message -like '*Re-run with DeploymentType Server and ServerUri set to the server root.*'
}

function Read-GerberAdoNewConnectionProfileName {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandLabel,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$ExistingProfileList,

        [Parameter(Mandatory)]
        [uri]$ProjectUri
    )

    while ($true) {
        $profileName = Read-GerberAdoSetupTextValue `
            -CommandLabel $CommandLabel `
            -Prompt 'Connection name'
        try {
            Assert-GerberAdoConnectionProfileLookupName -Name $profileName
            Assert-GerberAdoNewConnectionProfileName `
                -ProfileName $profileName `
                -ExistingProfileList $ExistingProfileList
            return $profileName
        } catch [System.ArgumentException] {
            $message = @(
                $_.Exception.Message
                ''
                "Project URL: $($ProjectUri.AbsoluteUri)"
            ) -join [Environment]::NewLine
            Show-GerberAdoSetupValidationError -CommandLabel $CommandLabel -Message $message
        }
    }
}

function Assert-GerberAdoNewConnectionProfileName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProfileName,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$ExistingProfileList
    )

    foreach ($existingProfile in @($ExistingProfileList)) {
        if ($existingProfile.Name.Equals($ProfileName, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw [System.ArgumentException]::new(
                "Gerber Azure DevOps profile '$ProfileName' already exists. Choose another connection name or use the existing profile."
            )
        }
    }
}

function Save-GerberAdoConnectionProfileConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Configuration,

        [Parameter(Mandatory)]
        [string]$ProfileName,

        [Parameter(Mandatory)]
        [pscustomobject]$ProjectResolution,

        [Parameter(Mandatory)]
        [bool]$SetAsDefault
    )

    $candidateConfiguration = Copy-GerberUserConfigurationMap -Configuration $Configuration
    $adoConfiguration = Get-GerberOrAddConfigurationSection -Configuration $candidateConfiguration -PropertyName 'ado'
    $profileTable = Get-GerberOrAddConfigurationSection -Configuration $adoConfiguration -PropertyName 'profiles'
    $profileTable[$ProfileName] = Get-GerberAdoConnectionProfileConfigMap -ProjectResolution $ProjectResolution
    if ($SetAsDefault) {
        $adoConfiguration['defaultProfile'] = $ProfileName
    }

    $null = Test-GerberUserConfiguration -Configuration $candidateConfiguration -Path (Resolve-GerberUserConfigPath)
    Save-GerberUserConfiguration -Configuration $candidateConfiguration
}

function Get-GerberAdoConnectionProfileConfigMap {
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$ProjectResolution
    )

    $profileMap = [ordered]@{
        projectUrl = $ProjectResolution.ProjectUri.AbsoluteUri.TrimEnd('/')
    }
    if ($ProjectResolution.DeploymentType -eq 'Server') {
        $profileMap['deploymentType'] = 'Server'
        $profileMap['serverUrl'] = $ProjectResolution.ServerUri.AbsoluteUri.TrimEnd('/')
    }

    return $profileMap
}

function Resolve-GerberAdoConnectionPat {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$ConnectionProfile,

        [Parameter(Mandatory)]
        [string]$PatIdentifier,

        [Parameter(Mandatory)]
        [string]$CommandLabel
    )

    $pat = Get-GerberCredential -Identifier $PatIdentifier
    if (-not [string]::IsNullOrWhiteSpace($pat)) {
        return $pat
    }

    Assert-GerberAdoInteractiveSetupAvailable `
        -CommandLabel $CommandLabel `
        -Reason "Azure DevOps profile '$($ConnectionProfile.ProfileName)' has no stored PAT"

    $screenText = @(
        "Azure DevOps connection: $($ConnectionProfile.ProfileName)"
        "Project: $($ConnectionProfile.ProjectUri.AbsoluteUri)"
        ''
        'No Personal Access Token is configured.'
        ''
        'Would you like to configure one now?'
    ) -join [Environment]::NewLine
    if (-not (Read-GerberAdoSetupConfirmation `
            -CommandLabel $CommandLabel `
            -ScreenText $screenText `
            -Prompt 'Configure PAT')) {
        throw (Get-GerberMenuEscapeException)
    }

    return Save-GerberAdoConnectionPat `
        -CommandLabel $CommandLabel `
        -ProfileName $ConnectionProfile.ProfileName
}

function Save-GerberAdoConnectionPat {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandLabel,

        [Parameter(Mandatory)]
        [string]$ProfileName
    )

    $credentialIdentifier = Get-GerberAdoCredentialIdentifier -ProfileName $ProfileName
    Confirm-GerberAdoConnectionPatOverwrite `
        -CommandLabel $CommandLabel `
        -ProfileName $ProfileName `
        -Identifier $credentialIdentifier

    while ($true) {
        try {
            $pat = Read-GerberAdoConnectionPatValue -Identifier $credentialIdentifier
            return $pat
        } catch [System.ArgumentException] {
            Show-GerberAdoSetupValidationError -CommandLabel $CommandLabel -Message $_.Exception.Message
        }
    }
}

function Confirm-GerberAdoConnectionPatOverwrite {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandLabel,

        [Parameter(Mandatory)]
        [string]$ProfileName,

        [Parameter(Mandatory)]
        [string]$Identifier
    )

    if (-not (Test-GerberCredential -Identifier $Identifier)) {
        return
    }

    $screenText = @(
        "Azure DevOps connection: $ProfileName"
        "Credential: $Identifier"
        ''
        'A Personal Access Token is already stored.'
        ''
        'Overwrite the stored token?'
    ) -join [Environment]::NewLine
    if (-not (Read-GerberAdoSetupConfirmation `
            -CommandLabel $CommandLabel `
            -ScreenText $screenText `
            -Prompt 'Overwrite PAT')) {
        throw (Get-GerberMenuEscapeException)
    }
}

function Read-GerberAdoConnectionPatValue {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Identifier
    )

    $pat = ConvertTo-GerberSecretText -Value (Read-GerberSecureValue -Prompt 'Personal Access Token')
    if ([string]::IsNullOrWhiteSpace($pat)) {
        throw [System.ArgumentException]::new('Enter a Personal Access Token.')
    }

    Set-GerberCredential -Identifier $Identifier -Secret $pat | Out-Null
    return $pat
}

function Read-GerberAdoExistingConnectionProfile {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandLabel,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$ProfileList
    )

    while ($true) {
        $name = Read-GerberAdoSetupTextValue `
            -CommandLabel $CommandLabel `
            -ScreenText (Get-GerberAdoSetupSelectionText -ProfileList $ProfileList) `
            -Prompt 'Connection name'
        $selectedProfile = Get-GerberAdoConnectionProfileByName -ProfileList $ProfileList -Name $name
        if ($null -ne $selectedProfile) {
            return $selectedProfile
        }

        Show-GerberAdoSetupValidationError `
            -CommandLabel $CommandLabel `
            -Message "Gerber could not find Azure DevOps profile '$name'. Enter one of the displayed connection names."
    }
}

function Get-GerberAdoSetupSelectionText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$ProfileList
    )

    return @(
        'Multiple Azure DevOps connections are available:'
        ''
        foreach ($connectionProfileEntry in @($ProfileList)) {
            "- $($connectionProfileEntry.Name): $($connectionProfileEntry.ProjectUrl)"
        }
    ) -join [Environment]::NewLine
}

function Get-GerberAdoConnectionProfileByName {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$ProfileList,

        [Parameter(Mandatory)]
        [string]$Name
    )

    foreach ($connectionProfileEntry in @($ProfileList)) {
        if ($connectionProfileEntry.Name.Equals($Name, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $connectionProfileEntry
        }
    }

    return $null
}

function Read-GerberAdoSetupConfirmation {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandLabel,

        [Parameter(Mandatory)]
        [string]$ScreenText,

        [Parameter(Mandatory)]
        [string]$Prompt
    )

    while ($true) {
        $response = Read-GerberAdoSetupTextValue `
            -CommandLabel $CommandLabel `
            -ScreenText $ScreenText `
            -Prompt "$Prompt [Y/n]"
        if ([string]::IsNullOrWhiteSpace($response)) {
            return $true
        }

        switch ($response.Trim().ToLowerInvariant()) {
            'y' { return $true }
            'yes' { return $true }
            'n' { return $false }
            'no' { return $false }
            default {
                Show-GerberAdoSetupValidationError `
                    -CommandLabel $CommandLabel `
                    -Message "Enter 'y' or 'n'."
            }
        }
    }
}

function Read-GerberAdoSetupTextValue {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandLabel,

        [string]$ScreenText,

        [Parameter(Mandatory)]
        [string]$Prompt
    )

    Start-GerberScreen -Name $CommandLabel
    Write-GerberScreenLine -Text $CommandLabel
    Write-GerberScreenLine
    if (-not [string]::IsNullOrWhiteSpace($ScreenText)) {
        foreach ($line in @($ScreenText -split "\r?\n")) {
            Write-GerberScreenLine -Text $line
        }
        Write-GerberScreenLine
    }

    return Read-GerberCommand -Prompt $Prompt -SuggestionMode 'None'
}

function Show-GerberAdoSetupValidationError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandLabel,

        [Parameter(Mandatory)]
        [string]$Message
    )

    Show-GerberTextBlock -Title $CommandLabel -Text $Message
    Wait-GerberContinue
}

function Assert-GerberAdoInteractiveSetupAvailable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandLabel,

        [Parameter(Mandatory)]
        [string]$Reason
    )

    if (-not (Test-GerberConsoleInputRedirected)) {
        return
    }

    $configPath = Resolve-GerberUserConfigPath
    throw [System.ArgumentException]::new(
        "Gerber could not continue $CommandLabel because $Reason. Configure Azure DevOps in '$configPath' and secure credential storage first, or rerun Gerber interactively."
    )
}

function Get-GerberSessionAdoProfile {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Configuration
    )

    $profileVariable = Get-Variable -Name 'GerberAdoSessionProfileName' -Scope Script -ErrorAction SilentlyContinue
    if ($null -eq $profileVariable -or [string]::IsNullOrWhiteSpace([string]$profileVariable.Value)) {
        return $null
    }

    $sessionConnectionProfile = Get-GerberAdoConnectionProfile -Name ([string]$profileVariable.Value) -Configuration $Configuration
    if ($null -ne $sessionConnectionProfile) {
        return $sessionConnectionProfile
    }

    $script:GerberAdoSessionProfileName = ''
    return $null
}

function Get-GerberResolvedAdoSelection {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProfileName
    )

    $script:GerberAdoSessionProfileName = $ProfileName
    return [pscustomobject]@{
        ProfileName = $ProfileName
    }
}
