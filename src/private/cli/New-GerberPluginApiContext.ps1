function New-GerberPluginApiContext {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$ApiVersion,

        [Parameter(Mandatory)]
        [guid]$PluginId
    )
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiContext', 'Invoke')

    switch ([string]$ApiVersion) {
        '1' {
            return [pscustomobject][ordered]@{
                ApiVersion = '1'
                PluginId   = $PluginId
                UI         = New-GerberPluginApiUiCapability
                Ado        = New-GerberPluginApiAdoCapability
                Secrets    = New-GerberPluginApiSecretsCapability -PluginId $PluginId
                Clipboard  = New-GerberPluginApiClipboardCapability
            }
        }
        default {
            $supportedVersionList = Get-GerberSupportedPluginApiVersionList
            throw [System.InvalidOperationException]::new(
                "Gerber plugin API version '$ApiVersion' is not supported. Supported plugin API versions: $($supportedVersionList -join ', ')."
            )
        }
    }
}

function Get-GerberSupportedPluginApiVersionList {
    [OutputType([string[]])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('Get-GerberSupportedPluginApiVersionList', 'Invoke')

    return [string[]]@('1')
}

function New-GerberPluginApiUiCapability {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiUiCapability', 'Invoke')

    return [pscustomobject][ordered]@{
        ReadSubcommand            = New-GerberPluginApiReadSubcommandOperation
        ShowTextBlock             = New-GerberPluginApiShowTextBlockOperation
        ShowScreenLines           = New-GerberPluginApiShowScreenLinesOperation
        ReadNumberedMenuSelection = New-GerberPluginApiReadNumberedMenuSelectionOperation
        ReadNumberedMenuPrompt    = New-GerberPluginApiReadNumberedMenuPromptOperation
        ReadCheckboxMenuPrompt    = New-GerberPluginApiReadCheckboxMenuPromptOperation
        ReadConfirmationPrompt    = New-GerberPluginApiReadConfirmationPromptOperation
        ReadCommand               = New-GerberPluginApiReadCommandOperation
        ReadSecretText            = New-GerberPluginApiReadSecretTextOperation
        StartScreen               = New-GerberPluginApiStartScreenOperation
        WriteScreenLine           = New-GerberPluginApiWriteScreenLineOperation
        WriteProgressBar          = New-GerberPluginApiWriteProgressBarOperation
        WritePromptTrace          = New-GerberPluginApiWritePromptTraceOperation
        WaitForContinue           = New-GerberPluginApiWaitForContinueOperation
    }
}

function New-GerberPluginApiReadSubcommandOperation {
    [OutputType([scriptblock])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiReadSubcommandOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param(
            [string]$CommandName,
            [pscustomobject]$Command,
            [System.Collections.IDictionary]$SubcommandTable
        )

        try {
            return Get-GerberMenuSubcommand -CommandName $CommandName -Command $Command -SubcommandTable $SubcommandTable
        } catch {
            if (Test-GerberMenuEscapeException -Exception $_.Exception) {
                return ''
            }

            throw
        }
    }
}

function New-GerberPluginApiReadCommandOperation {
    [OutputType([scriptblock])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiReadCommandOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param(
            [string]$Prompt,
            [string]$SuggestionMode,
            [string]$InputMode,
            [pscustomobject]$PromptContext,
            [bool]$TrimResult
        )

        return Read-GerberCommand `
            -Prompt $Prompt `
            -SuggestionMode $SuggestionMode `
            -InputMode $InputMode `
            -PromptContext $PromptContext `
            -TrimResult:$TrimResult
    }
}

function New-GerberPluginApiWriteProgressBarOperation {
    [OutputType([scriptblock])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiWriteProgressBarOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param(
            [int]$Current,
            [int]$Total,
            [string]$Prefix,
            [switch]$OverwritePreviousRender
        )

        Write-GerberProgressBar `
            -Current $Current `
            -Total $Total `
            -Prefix $Prefix `
            -OverwritePreviousRender:$OverwritePreviousRender
    }
}

function New-GerberPluginApiWritePromptTraceOperation {
    [OutputType([scriptblock])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiWritePromptTraceOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param(
            [string]$EventName,
            [System.Collections.IDictionary]$Data = @{}
        )

        Write-GerberPromptTrace -EventName $EventName -Data $Data
    }
}

function New-GerberPluginApiAdoCapability {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiAdoCapability', 'Invoke')
    $pullRequestOperationMap = Get-GerberPluginApiPullRequestOperationMap

    return [pscustomobject][ordered]@{
        OpenConnection                    = New-GerberPluginApiOpenAdoConnectionOperation
        ResolvePullRequestReference       = $pullRequestOperationMap['ResolvePullRequestReference']
        GetPullRequest                    = $pullRequestOperationMap['GetPullRequest']
        GetPullRequestChangedFileList     = $pullRequestOperationMap['GetPullRequestChangedFileList']
        GetPullRequestFileContent         = $pullRequestOperationMap['GetPullRequestFileContent']
        GetPullRequestBuildValidationStatus = $pullRequestOperationMap['GetPullRequestBuildValidationStatus']
        NewProjectUri                     = New-GerberPluginApiNewAdoProjectUriOperation
        InvokeGet                         = New-GerberPluginApiInvokeAdoGetOperation
        GetPendingApprovalList            = New-GerberPluginApiGetPendingApprovalListOperation
        GetEnvironmentList                = New-GerberPluginApiGetEnvironmentListOperation
        ResolvePipelineDefinitionFromUrl  = New-GerberPluginApiResolvePipelineDefinitionFromUrlOperation
        GetPipelineRunList                = New-GerberPluginApiGetPipelineRunListOperation
        StartPipelineRun                  = New-GerberPluginApiStartPipelineRunOperation
        WaitPipelineRunCompletion         = New-GerberPluginApiWaitPipelineRunCompletionOperation
        ApprovePipelineApproval           = New-GerberPluginApiApprovePipelineApprovalOperation
        StopPipelineRun                   = New-GerberPluginApiStopPipelineRunOperation
        GetBuildTagList                   = New-GerberPluginApiGetBuildTagListOperation
        AddBuildTagIfMissing             = New-GerberPluginApiAddBuildTagIfMissingOperation
        RemoveBuildTag                    = New-GerberPluginApiRemoveBuildTagOperation
        AddBuildRetentionLeaseIfMissing   = New-GerberPluginApiAddBuildRetentionLeaseIfMissingOperation
        GetBuildRunUrl                    = New-GerberPluginApiGetBuildRunUrlOperation
        GetWorkItemIdFromUrl              = New-GerberPluginApiGetWorkItemIdFromUrlOperation
        GetWorkItemFieldMap               = New-GerberPluginApiGetWorkItemFieldMapOperation
        UpdateWorkItemFields              = New-GerberPluginApiUpdateWorkItemFieldsOperation
    }
}

function New-GerberPluginApiOpenAdoConnectionOperation {
    [OutputType([scriptblock])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiOpenAdoConnectionOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param(
            [Parameter(Mandatory)]
            [string]$CommandLabel,

            [string]$ProfileName
        )

        $configuration = if ([string]::IsNullOrWhiteSpace($ProfileName)) {
            Get-GerberAdoConfiguration -CommandLabel $CommandLabel
        } else {
            Get-GerberAdoConfiguration -ProfileName $ProfileName -CommandLabel $CommandLabel
        }

        return New-GerberPluginApiAdoConnectionContext -Configuration $configuration -CommandLabel $CommandLabel
    }
}

function New-GerberPluginApiNewAdoProjectUriOperation {
    [OutputType([scriptblock])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiNewAdoProjectUriOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param(
            [Parameter(Mandatory)]
            [pscustomobject]$Connection,

            [Parameter(Mandatory)]
            [string]$RelativePath,

            [System.Collections.IDictionary]$QueryParameterMap = [ordered]@{}
        )

        $requestContext = Get-GerberPluginApiAdoRequestContext -Connection $Connection
        $configuration = $requestContext.Configuration
        $normalizedQueryParameterMap = Get-GerberPluginApiAdoQueryParameterMap `
            -QueryParameterMap $QueryParameterMap `
            -DefaultApiVersion $configuration.DefaultApiVersion
        $trimmedRelativePath = $RelativePath.Trim().TrimStart('/')

        return Get-GerberAdoApiUri `
            -BaseUri ([System.Uri]::new($configuration.CollectionUri, $trimmedRelativePath)) `
            -QueryParameterMap $normalizedQueryParameterMap
    }
}

function Get-GerberPluginApiAdoQueryParameterMap {
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [AllowNull()]
        [System.Collections.IDictionary]$QueryParameterMap,

        [Parameter(Mandatory)]
        [string]$DefaultApiVersion
    )
    $null = $PSCmdlet.ShouldProcess('Get-GerberPluginApiAdoQueryParameterMap', 'Invoke')

    $normalizedQueryParameterMap = [ordered]@{}
    foreach ($key in @($QueryParameterMap.Keys)) {
        $normalizedQueryParameterMap[[string]$key] = [string]$QueryParameterMap[$key]
    }

    if (-not $normalizedQueryParameterMap.Contains('api-version')) {
        $normalizedQueryParameterMap['api-version'] = $DefaultApiVersion
    }

    return $normalizedQueryParameterMap
}

function New-GerberPluginApiInvokeAdoGetOperation {
    [OutputType([scriptblock])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiInvokeAdoGetOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param(
            [Parameter(Mandatory)]
            [pscustomobject]$Connection,

            [Parameter(Mandatory)]
            [uri]$Uri,

            [Parameter(Mandatory)]
            [string]$RequestLabel
        )

        $requestContext = Get-GerberPluginApiAdoRequestContext -Connection $Connection -RequireAuthentication
        return Invoke-GerberAdoRestRequest `
            -Uri $Uri `
            -Pat $requestContext.Pat `
            -RequestLabel $RequestLabel `
            -CredentialIdentifier $requestContext.Configuration.CredentialIdentifier
    }
}

function New-GerberPluginApiUpdateWorkItemFieldsOperation {
        [OutputType([scriptblock])]
        [CmdletBinding(SupportsShouldProcess)]
        param()
        $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiUpdateWorkItemFieldsOperation', 'Invoke')

        return Get-GerberModuleBoundScriptBlock -ScriptBlock {
            param(
                [pscustomobject]$UpdateRequest
            )

            $resolvedRequest = Set-GerberPluginApiRequestConfiguration -Request $UpdateRequest
            Update-GerberAdoWorkItemFieldMap -UpdateRequest $resolvedRequest
        }
    }

function Set-GerberPluginApiRequestConfiguration {
        [OutputType([pscustomobject])]
        [CmdletBinding(SupportsShouldProcess)]
        param(
            [Parameter(Mandatory)]
            [pscustomobject]$Request
        )
        $null = $PSCmdlet.ShouldProcess('Set-GerberPluginApiRequestConfiguration', 'Invoke')

        $resolvedPropertyMap = [ordered]@{}
        foreach ($property in $Request.PSObject.Properties) {
            $resolvedPropertyMap[$property.Name] = $property.Value
        }

        if ($resolvedPropertyMap.Contains('Connection')) {
            $requestContext = Get-GerberPluginApiAdoRequestContext `
                -Connection $resolvedPropertyMap.Connection `
                -RequireAuthentication
            $resolvedPropertyMap['Configuration'] = $requestContext.Configuration
            $resolvedPropertyMap['Pat'] = $requestContext.Pat
        } else {
            throw [System.ArgumentException]::new(
                'Gerber plugin ADO request operations require a connection created by Gerber.Ado.OpenConnection.'
            )
        }

        return [pscustomobject]$resolvedPropertyMap
    }

function Get-GerberPluginApiAdoRequestContext {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Connection,

        [switch]$RequireAuthentication
    )
    $null = $PSCmdlet.ShouldProcess('Get-GerberPluginApiAdoRequestContext', 'Invoke')

    $configuration = Get-GerberPluginApiAdoConnectionConfiguration -Connection $Connection
    $propertyMap = [ordered]@{
        Configuration = $configuration
    }
    if ($RequireAuthentication) {
        $propertyMap['Pat'] = Resolve-GerberAdoPat `
            -Configuration $configuration `
            -CommandLabel (Get-GerberPluginApiAdoCommandLabel -Connection $Connection)
    }

    return [pscustomobject]$propertyMap
}

function Get-GerberPluginApiAdoConnectionPat {
    [OutputType([string])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Connection
    )
    $null = $PSCmdlet.ShouldProcess('Get-GerberPluginApiAdoConnectionPat', 'Invoke')

    return [string](Get-GerberPluginApiAdoRequestContext -Connection $Connection -RequireAuthentication).Pat
}

function New-GerberPluginApiAdoConnectionContext {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$CommandLabel
    )
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiAdoConnectionContext', 'Invoke')

    return [pscustomobject][ordered]@{
        Id             = [guid]::NewGuid().ToString('N')
        CommandLabel   = $CommandLabel
        ProfileName    = $Configuration.ProfileName
        DeploymentType = $Configuration.DeploymentType
        ServerUri      = $Configuration.ServerUri
        Organization   = $Configuration.Organization
        Collection     = $Configuration.Collection
        CollectionName = $Configuration.CollectionName
        CollectionUri  = $Configuration.CollectionUri
        ProjectName    = $Configuration.ProjectName
        ProjectUri     = $Configuration.ProjectUri
    }
}

function Get-GerberPluginApiAdoConnectionConfiguration {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Connection
    )
    $null = $PSCmdlet.ShouldProcess('Get-GerberPluginApiAdoConnectionConfiguration', 'Invoke')

    $connectionProfile = ConvertTo-GerberPluginApiAdoConnectionProfile -Connection $Connection
    return Get-GerberAdoConfiguration -ConnectionProfile $connectionProfile
}

function Get-GerberPluginApiAdoCommandLabel {
    [OutputType([string])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Connection
    )
    $null = $PSCmdlet.ShouldProcess('Get-GerberPluginApiAdoCommandLabel', 'Invoke')

    if ($Connection.PSObject.Properties.Match('CommandLabel').Count -eq 0) {
        return 'the requested Azure DevOps operation'
    }

    $commandLabel = [string]$Connection.CommandLabel
    if ([string]::IsNullOrWhiteSpace($commandLabel)) {
        return 'the requested Azure DevOps operation'
    }

    return $commandLabel
}

function ConvertTo-GerberPluginApiAdoConnectionProfile {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Connection
    )
    $null = $PSCmdlet.ShouldProcess('ConvertTo-GerberPluginApiAdoConnectionProfile', 'Invoke')

    $profileName = Get-GerberPluginApiAdoConnectionPropertyValue -Connection $Connection -PropertyName 'ProfileName'
    $deploymentType = Get-GerberPluginApiAdoConnectionPropertyValue -Connection $Connection -PropertyName 'DeploymentType'
    $serverUri = Get-GerberPluginApiAdoConnectionPropertyValue -Connection $Connection -PropertyName 'ServerUri'
    $organization = Get-GerberPluginApiOptionalAdoConnectionPropertyValue -Connection $Connection -PropertyName 'Organization'
    $collection = Get-GerberPluginApiOptionalAdoConnectionPropertyValue -Connection $Connection -PropertyName 'Collection'
    $projectName = Get-GerberPluginApiAdoConnectionPropertyValue -Connection $Connection -PropertyName 'ProjectName'
    $projectUri = Get-GerberPluginApiAdoConnectionPropertyValue -Connection $Connection -PropertyName 'ProjectUri'

    return [pscustomobject][ordered]@{
        ProfileName    = $profileName
        DeploymentType = $deploymentType
        ServerUri      = [uri]$serverUri
        Organization   = $organization
        Collection     = $collection
        Project        = $projectName
        ProjectUri     = [uri]$projectUri
    }
}

function Get-GerberPluginApiAdoConnectionPropertyValue {
    [OutputType([string])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Connection,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )
    $null = $PSCmdlet.ShouldProcess('Get-GerberPluginApiAdoConnectionPropertyValue', 'Invoke')

    if ($Connection.PSObject.Properties.Match($PropertyName).Count -eq 0) {
        throw [System.ArgumentException]::new(
            'Gerber plugin ADO operations require a connection created by Gerber.Ado.OpenConnection.'
        )
    }

    $value = [string]$Connection.$PropertyName
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw [System.ArgumentException]::new(
            'Gerber plugin ADO operations require a connection created by Gerber.Ado.OpenConnection.'
        )
    }

    return $value
}

function Get-GerberPluginApiOptionalAdoConnectionPropertyValue {
    [OutputType([string])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Connection,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )
    $null = $PSCmdlet.ShouldProcess('Get-GerberPluginApiOptionalAdoConnectionPropertyValue', 'Invoke')

    if ($Connection.PSObject.Properties.Match($PropertyName).Count -eq 0) {
        return ''
    }

    return [string]$Connection.$PropertyName
}

function New-GerberPluginApiSecretsCapability {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [guid]$PluginId
    )
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiSecretsCapability', 'Invoke')

    $pluginIdLiteral = $PluginId.ToString()
    return [pscustomobject][ordered]@{
        EnsureReady = Get-GerberModuleBoundScriptBlock -ScriptBlock ([scriptblock]::Create(@'
            param(
                [string]$ActionLabel,
                [string]$ScreenTitle
            )

            $null = $ActionLabel, $ScreenTitle
            return Use-GerberCredentialStore
'@))
        Test       = Get-GerberModuleBoundScriptBlock -ScriptBlock ([scriptblock]::Create(@"
            param(
                [string[]]`$PathSegmentList
            )

            `$identifier = Get-GerberPluginCredentialIdentifier -PluginId ([guid]'$pluginIdLiteral') -PathSegmentList `$PathSegmentList
            return Test-GerberCredential -Identifier `$identifier
"@))
        GetText    = Get-GerberModuleBoundScriptBlock -ScriptBlock ([scriptblock]::Create(@"
            param(
                [string[]]`$PathSegmentList
            )

            `$identifier = Get-GerberPluginCredentialIdentifier -PluginId ([guid]'$pluginIdLiteral') -PathSegmentList `$PathSegmentList
            return Get-GerberCredential -Identifier `$identifier
"@))
        Set        = Get-GerberModuleBoundScriptBlock -ScriptBlock ([scriptblock]::Create(@"
            param(
                [string[]]`$PathSegmentList,
                [object]`$Secret
            )

            `$identifier = Get-GerberPluginCredentialIdentifier -PluginId ([guid]'$pluginIdLiteral') -PathSegmentList `$PathSegmentList
            Set-GerberCredential -Identifier `$identifier -Secret (ConvertTo-GerberSecretText -Value `$Secret)
"@))
        Remove     = Get-GerberModuleBoundScriptBlock -ScriptBlock ([scriptblock]::Create(@"
            param(
                [string[]]`$PathSegmentList
            )

            `$identifier = Get-GerberPluginCredentialIdentifier -PluginId ([guid]'$pluginIdLiteral') -PathSegmentList `$PathSegmentList
            return Remove-GerberCredential -Identifier `$identifier
"@))
    }
}

function New-GerberPluginApiClipboardCapability {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiClipboardCapability', 'Invoke')

    return [pscustomobject][ordered]@{
        CopyText = Get-GerberModuleBoundScriptBlock -ScriptBlock {
            param(
                [string]$Value
            )

            return Copy-GerberValueToClipboard -Value $Value
        }
    }
}
