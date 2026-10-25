function Show-GerberRepositoryCreateView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Command
    )

    $null = $Command

    while ($true) {
        Write-GerberPromptTrace -EventName 'nav-create-outer-loop' -Data @{}
        Show-GerberRepositoryCreateHeader
        $projectSelection = Read-GerberRepositoryCreateProjectOrNull
        if ($null -eq $projectSelection) {
            Write-GerberPromptTrace -EventName 'nav-create-return' -Data @{ Reason = 'project-esc' }
            return
        }

        Invoke-GerberRepositoryCreateTemplateLoop -ProjectSelection $projectSelection
    }
}

function Invoke-GerberRepositoryCreateTemplateLoop {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$ProjectSelection
    )

    while ($true) {
        Write-GerberPromptTrace -EventName 'nav-create-inner-loop' -Data @{}
        Show-GerberRepositoryCreateHeader
        $templateSelection = Read-GerberRepositoryCreateTemplateOrNull -ProjectSelection $ProjectSelection
        if ($null -eq $templateSelection) {
            Write-GerberPromptTrace -EventName 'nav-create-inner-break' -Data @{ Reason = 'template-esc' }
            break
        }
        $null = Invoke-GerberRepositoryCreateTemplateAction -ProjectSelection $ProjectSelection -TemplateSelection $templateSelection
    }
}

function Invoke-GerberRepositoryCreateTemplateAction {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$ProjectSelection,

        [Parameter(Mandatory)]
        [pscustomobject]$TemplateSelection
    )

    return Invoke-GerberRepositoryCreateFromTemplateFlow -ProjectSelection $ProjectSelection -TemplateSelection $TemplateSelection
}

function Show-GerberRepositoryCreateHeader {
    [CmdletBinding()]
    param()

    Start-GerberScreen -Name '/repository create'
    Write-GerberScreenLine -Text '/repository create'
    Write-GerberScreenLine
}

function Read-GerberRepositoryCreateTemplateOrNull {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$ProjectSelection
    )

    $configuration = Get-GerberAdoConfiguration
    $pat = Resolve-GerberAdoPat -Configuration $configuration
    $templateList = @(Get-GerberAdoRepositoryTemplateList -Configuration $configuration -Pat $pat -ProjectName $ProjectSelection.Name)
    $menuItems = @(
        foreach ($template in $templateList) {
            [pscustomobject]@{
                Label         = $template.Name
                Value         = $template.Name
            }
        }
    )

    if (-not $menuItems) {
        Show-GerberMenuError -Message "No template repositories found in project '$($ProjectSelection.Name)'."
        return $null
    }

    $numberedItems = @(Convert-GerberListToNumberedMenuItemList -ItemList $menuItems -DisplayProperty 'Label' -ValueProperty 'Value')

    try {
        $selection = Read-GerberNumberedMenuPrompt -Prompt 'Template' -MenuItemList $numberedItems
        return $templateList | Where-Object { $_.Name -eq $selection } | Select-Object -First 1
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) {
            return $null
        }
        throw
    }
}

function Read-GerberRepositoryCreateProjectOrNull {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param()

    $configuration = Get-GerberAdoConfiguration
    $pat = Resolve-GerberAdoPat -Configuration $configuration
    $projectList = @(Get-GerberAdoProjectList -Configuration $configuration -Pat $pat)
    $menuItems = @(Convert-GerberListToNumberedMenuItemList -ItemList $projectList -DisplayProperty 'Name')
    try {
        $selection = Read-GerberNumberedMenuPrompt -Prompt 'Project' -MenuItemList $menuItems
        return $projectList | Where-Object { $_.Name -eq $selection } | Select-Object -First 1
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) {
            return $null
        }
        throw
    }
}
