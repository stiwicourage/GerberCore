function Show-GerberAdoTeamMemberReport {
    [CmdletBinding()]
    param()

    Start-GerberScreen -Name '/list ado-team-members'
    Write-GerberScreenLine -Text '/list ado-team-members'
    Write-GerberScreenLine
    Write-GerberScreenLine -Text 'Connecting to Azure DevOps...'
    $report = Get-GerberAdoTeamMemberReport
    $drawSummary = { Show-GerberAdoTeamMemberSummaryScreen -Report $report }
    Show-GerberAdoTeamMemberExportPrompt -Report $report -DrawScreen $drawSummary
    Show-GerberAdoTeamMemberDrillIn -Report $report
}

function Show-GerberAdoTeamMemberSummaryScreen {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Report
    )

    Start-GerberScreen -Name '/list ado-team-members'
    Write-GerberScreenLine -Text '/list ado-team-members'
    Write-GerberScreenLine
    Show-GerberAdoTeamMemberSummary -Report $Report
    Write-GerberScreenLine
}

function Show-GerberAdoTeamMemberSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Report
    )

    Write-GerberAdoColorLine -Text '=== Projects and Teams ===' -ForegroundColor Yellow
    if (@($Report.ProjectList).Count -eq 0) {
        Write-GerberAdoColorLine -Text 'No projects found.' -ForegroundColor DarkYellow
        return
    }

    foreach ($project in @($Report.ProjectList)) {
        Write-GerberAdoColorLine -Text $project.Name -ForegroundColor Cyan
        foreach ($team in @($project.TeamList)) {
            Write-GerberScreenLine -Text "  $($team.Name) ($(@($team.MemberList).Count) members)"
        }
    }
}

function Show-GerberAdoTeamMemberExportPrompt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Report,

        [Parameter(Mandatory)]
        [scriptblock]$DrawScreen,

        [object[]]$DrawScreenArgumentList = @()
    )

    $continueLoop = $true
    while ($continueLoop) {
        & $DrawScreen @DrawScreenArgumentList
        $selection = Read-GerberNumberedMenuPrompt `
            -Prompt 'Export or continue' `
            -MenuItemList (Get-GerberAdoTeamMemberExportMenuItemList)
        $continueLoop = Invoke-GerberAdoTeamMemberExportSelection -Report $Report -Selection $selection
    }
}

function Invoke-GerberAdoTeamMemberExportSelection {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Report,

        [Parameter(Mandatory)]
        [string]$Selection
    )

    if ($Selection -in 'json', 'csv', 'html') {
        Export-GerberAdoTeamMemberReport -Report $Report -Format $Selection
        return $true
    }
    return $false
}

function Show-GerberAdoTeamMemberDrillIn {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Report
    )

    if (@($Report.ProjectList).Count -eq 0) { return }
    while ($true) {
        $projectId = Read-GerberAdoProjectMenuChoice -Report $Report
        if ([string]::IsNullOrWhiteSpace($projectId)) { return }
        $project = @($Report.ProjectList | Where-Object { $_.Id -eq $projectId })[0]
        Show-GerberAdoTeamChooser -Report $Report -Project $project
    }
}

function Show-GerberAdoTeamChooser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Report,

        [Parameter(Mandatory)]
        [pscustomobject]$Project
    )

    while ($true) {
        $teamId = Read-GerberAdoTeamMenuChoice -Project $Project
        if ([string]::IsNullOrWhiteSpace($teamId)) { return }
        $team = @($Project.TeamList | Where-Object { $_.Id -eq $teamId })[0]
        Show-GerberAdoMemberListScreen -Report $Report -Project $Project -Team $team
    }
}

function Read-GerberAdoProjectMenuChoice {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Report
    )

    Start-GerberScreen -Name '/list ado-team-members'
    Write-GerberScreenLine -Text '/list ado-team-members'
    Write-GerberScreenLine
    Show-GerberAdoTeamMemberSummary -Report $Report
    Write-GerberScreenLine
    $menuItems = Get-GerberAdoProjectMenuItemList -ProjectList @($Report.ProjectList)
    try {
        return Read-GerberNumberedMenuPrompt -Prompt 'Select project (Esc to go back)' -MenuItemList $menuItems
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) { return '' }
        throw
    }
}

function Read-GerberAdoTeamMenuChoice {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Project
    )

    Start-GerberScreen -Name '/list ado-team-members'
    Write-GerberScreenLine -Text '/list ado-team-members'
    Write-GerberScreenLine
    Write-GerberAdoColorLine -Text $Project.Name -ForegroundColor Cyan
    if (@($Project.TeamList).Count -eq 0) {
        Write-GerberAdoColorLine -Text '  (No teams in this project)' -ForegroundColor DarkYellow
        Write-GerberScreenLine
        return ''
    }

    $menuItems = Get-GerberAdoTeamMenuItemList -TeamList @($Project.TeamList)
    try {
        return Read-GerberNumberedMenuPrompt -Prompt 'Select team (Esc to go back)' -MenuItemList $menuItems
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) { return '' }
        throw
    }
}

function Show-GerberAdoMemberListScreen {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Report,

        [Parameter(Mandatory)]
        [pscustomobject]$Project,

        [Parameter(Mandatory)]
        [pscustomobject]$Team
    )

    $null = $Project, $Team
    $drawScreen = {
        param(
            [pscustomobject]$SelectedProject,
            [pscustomobject]$SelectedTeam
        )

        Start-GerberScreen -Name '/list ado-team-members'
        Write-GerberScreenLine -Text '/list ado-team-members'
        Write-GerberScreenLine
        Write-GerberAdoColorLine -Text "$($SelectedProject.Name) › $($SelectedTeam.Name)" -ForegroundColor Cyan
        Write-GerberScreenLine
        Write-GerberAdoMemberListContent -Team $SelectedTeam
        Write-GerberScreenLine
    }
    try {
        Show-GerberAdoTeamMemberExportPrompt `
            -Report $Report `
            -DrawScreen $drawScreen `
            -DrawScreenArgumentList @($Project, $Team)
    } catch {
        if (Test-GerberMenuEscapeException -Exception $_.Exception) { return }
        throw
    }
}

function Write-GerberAdoMemberListContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Team
    )

    if (@($Team.MemberList).Count -eq 0) {
        Write-GerberAdoColorLine -Text '  (No members in this team)' -ForegroundColor DarkYellow
        return
    }

    foreach ($member in @($Team.MemberList)) {
        Write-GerberScreenLine -Text "  $($member.DisplayName) ($($member.UniqueName))"
    }
}

function Build-GerberAdoNumberedMenuItemList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$ItemList,

        [Parameter(Mandatory)]
        [scriptblock]$GetPreviewText
    )

    return @(
        for ($i = 0; $i -lt $ItemList.Count; $i++) {
            $item = $ItemList[$i]
            [pscustomobject]@{
                Number      = $i + 1
                Label       = $item.Name
                Value       = $item.Id
                PreviewText = & $GetPreviewText $item
            }
        }
    )
}

function Get-GerberAdoProjectMenuItemList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$ProjectList
    )

    Build-GerberAdoNumberedMenuItemList -ItemList $ProjectList `
        -GetPreviewText { param($p) "$(@($p.TeamList).Count) team(s)" }
}

function Get-GerberAdoTeamMenuItemList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$TeamList
    )

    $memberCountFn = { param($t) "$(@($t.MemberList).Count) member(s)" }
    Build-GerberAdoNumberedMenuItemList -ItemList $TeamList -GetPreviewText $memberCountFn
}

function Get-GerberAdoTeamMemberExportMenuItemList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param()

    return @(
        [pscustomobject]@{ Number = 1; Label = 'Continue'; Value = 'continue'; PreviewText = 'Continue without exporting' }
        [pscustomobject]@{ Number = 2; Label = 'Export JSON'; Value = 'json'; PreviewText = 'Export full report as JSON' }
        [pscustomobject]@{ Number = 3; Label = 'Export CSV'; Value = 'csv'; PreviewText = 'Export flat CSV with all members' }
        [pscustomobject]@{ Number = 4; Label = 'Export HTML'; Value = 'html'; PreviewText = 'Export HTML with browser search' }
    )
}

function Export-GerberAdoTeamMemberReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Report,

        [Parameter(Mandatory)]
        [ValidateSet('json', 'csv', 'html')]
        [string]$Format
    )

    $baseName = Get-GerberAdoTeamMemberExportBaseName
    $filePath = Join-Path (Get-Location).Path "$baseName.$Format"
    switch ($Format) {
        'json' { $Report | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Encoding utf8NoBOM }
        'csv'  { Get-GerberAdoTeamMemberCsvRowList -Report $Report | Export-Csv -Path $filePath -NoTypeInformation }
        'html' { Set-Content -Path $filePath -Value (Get-GerberAdoTeamMemberHtmlContent -Report $Report) -Encoding utf8NoBOM }
    }
    Write-GerberScreenLine -Text "Exported $($Format.ToUpper()) to: $filePath"
}

function Get-GerberAdoTeamMemberCsvRowList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Report
    )

    return @(
        foreach ($project in @($Report.ProjectList)) {
            foreach ($team in @($project.TeamList)) {
                foreach ($member in @($team.MemberList)) {
                    [pscustomobject]@{
                        Project = $project.Name
                        Team = $team.Name
                        DisplayName = $member.DisplayName
                        UniqueName = $member.UniqueName
                    }
                }
            }
        }
    )
}

function Get-GerberAdoTeamMemberHtmlContent {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Report
    )

    $rows = Get-GerberAdoTeamMemberHtmlRowList -Report $Report
    return @"
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>ADO Team Members</title>
<style>body{font-family:sans-serif;margin:16px}table{border-collapse:collapse;width:100%}th,td{border:1px solid #ccc;padding:8px;text-align:left}th{background:#f0f0f0}#search{margin:8px 0;padding:6px;width:300px}</style>
<script>function filterTable(){var v=document.getElementById('search').value.toLowerCase();[].slice.call(document.querySelectorAll('tbody tr')).forEach(function(r){r.style.display=r.textContent.toLowerCase().indexOf(v)>-1?'':'none';});}</script>
</head><body>
<h1>Azure DevOps Team Members</h1>
<input id="search" type="text" placeholder="Filter rows..." oninput="filterTable()">
<table><thead><tr><th>Project</th><th>Team</th><th>Display Name</th><th>Unique Name</th></tr></thead>
<tbody>$rows</tbody></table></body></html>
"@
}

function Get-GerberAdoTeamMemberHtmlRowList {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Report
    )

    $sb = [System.Text.StringBuilder]::new()
    foreach ($project in @($Report.ProjectList)) {
        foreach ($team in @($project.TeamList)) {
            foreach ($member in @($team.MemberList)) {
                $pName = $project.Name -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;'
                $tName = $team.Name -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;'
                $dName = $member.DisplayName -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;'
                $uName = $member.UniqueName -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;'
                $null = $sb.Append("<tr><td>$pName</td><td>$tName</td><td>$dName</td><td>$uName</td></tr>")
            }
        }
    }

    return $sb.ToString()
}

function Get-GerberAdoTeamMemberExportBaseName {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    $timestamp = [datetime]::Now.ToString('yyyyMMdd-HHmmss')
    return "gerber-ado-team-members-$timestamp"
}
