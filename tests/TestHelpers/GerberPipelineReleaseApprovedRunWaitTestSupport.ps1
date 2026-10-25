function Get-ApprovedRunWaitRequest {
    param(
        [pscustomobject]$Options = [pscustomobject]@{},
        [switch]$IncludeProgressContext
    )

    $settings = [pscustomobject]@{
        TimeoutSeconds     = 1
        PollIntervalSeconds = 0
        DefinitionId       = 313
        BuildId            = 72513
        PipelineLabel      = 'Sitecore'
        ItemId             = '3:0'
        RowIndex           = 3
        RenderState        = [pscustomobject]@{}
    }
    Copy-ObjectProperty -InputObject $Options -TargetObject $settings

    $waitRequest = [ordered]@{
        Configuration           = [pscustomobject]@{}
        Pat                     = 'pat'
        DefinitionId            = $settings.DefinitionId
        BranchName              = 'main'
        BuildId                 = $settings.BuildId
        SelectedEnvironmentName = 'PreProd'
        TimeoutSeconds          = $settings.TimeoutSeconds
        PollIntervalSeconds     = $settings.PollIntervalSeconds
    }

    if ($IncludeProgressContext) {
        $waitRequest.ProgressContext = Get-ApprovedRunWaitProgressContext `
            -Options ([pscustomobject]@{
                PipelineLabel = $settings.PipelineLabel
                ItemId        = $settings.ItemId
                RowIndex      = $settings.RowIndex
                RunId         = $settings.BuildId
                RenderState   = $settings.RenderState
            })
    }

    return [pscustomobject]$waitRequest
}

function Get-ApprovedRunListEntry {
    param(
        [pscustomobject]$Options = [pscustomobject]@{}
    )

    $settings = [pscustomobject]@{
        BuildId                          = 72513
        BuildNumber                      = '20260607.2'
        Status                           = ''
        Result                           = ''
        EnvironmentName                  = ''
        PendingApprovalEnvironmentNameList = @()
        ApprovalEnvironmentMap           = @{}
    }
    Copy-ObjectProperty -InputObject $Options -TargetObject $settings

    return [pscustomobject]@{
        BuildId                          = $settings.BuildId
        BuildNumber                      = $settings.BuildNumber
        Status                           = $settings.Status
        Result                           = $settings.Result
        EnvironmentName                  = $settings.EnvironmentName
        PendingApprovalEnvironmentNameList = @($settings.PendingApprovalEnvironmentNameList)
        ApprovalEnvironmentMap           = $settings.ApprovalEnvironmentMap
        RunUrl                           = "https://ado/_build/results?buildId=$($settings.BuildId)"
    }
}

function Get-ApprovedRunWaitProgressContext {
    param(
        [pscustomobject]$Options = [pscustomobject]@{}
    )

    $settings = [pscustomobject]@{
        PipelineLabel = 'Sitecore'
        ItemId        = '3:0'
        RowIndex      = 3
        RunId         = 72513
        RenderState   = [pscustomobject]@{}
    }
    Copy-ObjectProperty -InputObject $Options -TargetObject $settings

    return [pscustomobject]@{
        Configuration = [pscustomobject]@{
            CollectionUri = [uri]'https://ado/'
            ProjectName   = 'Test'
        }
        Entry = [pscustomobject]@{
            PipelineLabel = $settings.PipelineLabel
            ItemId        = $settings.ItemId
            RowIndex      = $settings.RowIndex
        }
        RunId       = $settings.RunId
        RenderState = $settings.RenderState
    }
}

function Get-ApprovedRunStateSequence {
    param(
        [pscustomobject]$RunningOptions = [pscustomobject]@{},
        [pscustomobject]$CompletedOptions = [pscustomobject]@{}
    )

    $running = [pscustomobject]@{
        BuildId         = 72513
        BuildNumber     = '20260607.2'
        Status          = 'inProgress'
        Result          = ''
        EnvironmentName = 'PreProd'
    }
    $completed = [pscustomobject]@{
        BuildId         = 72513
        BuildNumber     = '20260607.2'
        Status          = 'completed'
        Result          = 'succeeded'
        EnvironmentName = ''
    }
    Copy-ObjectProperty -InputObject $RunningOptions -TargetObject $running
    Copy-ObjectProperty -InputObject $CompletedOptions -TargetObject $completed

    return @(
        (Get-ApprovedRunListEntry -Options $running)
        (Get-ApprovedRunListEntry -Options $completed)
    )
}

function Copy-ObjectProperty {
    param(
        [psobject]$InputObject,
        [psobject]$TargetObject
    )

    if ($null -eq $InputObject) {
        return
    }

    foreach ($property in $InputObject.PSObject.Properties) {
        $TargetObject.$($property.Name) = $property.Value
    }
}
