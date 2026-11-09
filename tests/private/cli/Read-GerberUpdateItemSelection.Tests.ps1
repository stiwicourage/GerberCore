BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $source = "$root/src/private/cli/Read-GerberUpdateItemSelection.ps1"
    if (Test-Path $source) {
        . $source
    }
    . "$root/src/private/cli/Format-GerberUpdateItemOverview.ps1"
    . "$root/src/private/cli/Format-GerberUpdateItemListOverview.ps1"
    function Read-GerberCheckboxMenuPrompt {
        param($PromptRequest)
        $null = $PromptRequest
    }
}

Describe 'Read-GerberUpdateItemSelection' -Tag 'G4A9UI' {
    It 'excludes unavailable rows and returns exact selected item values, initially unchecked' {
        $available = [pscustomobject]@{
            Kind = 'Plugin'; State = [pscustomobject]@{
                Status = 'Available'; Name = 'ExamplePlugin'; Installed = '1.0.0'; Available = '2.0.0'; Repository = 'Feed'; Message = ''
            }
        }
        $blocked = [pscustomobject]@{
            Kind = 'Plugin'; State = [pscustomobject]@{
                Status = 'Blocked'; Name = 'BlockedPlugin'; Installed = '1.0.0'; Available = '-'; Repository = 'Feed'; Message = 'No permitted package.'
            }
        }
        Mock Read-GerberCheckboxMenuPrompt {
            [pscustomobject]@{
                SelectedValueList = @($available)
            }
        }
        $selected = @(Read-GerberUpdateItemSelection -ItemList @($available, $blocked))
        [object]::ReferenceEquals($selected[0], $available) | Should -BeTrue
        Should -Invoke Read-GerberCheckboxMenuPrompt -ParameterFilter {
            $PromptRequest.ItemList.Count -eq 1 -and -not $PromptRequest.ItemList[0].IsSelected -and
            $PromptRequest.AllowEmptySelection -and
            $PromptRequest.ScreenText -match 'BlockedPlugin.*Blocked' -and
            $PromptRequest.ScreenText -notmatch 'BlockedPlugin:|No permitted package'
        }
        Should -Invoke Read-GerberCheckboxMenuPrompt -ParameterFilter {
            $PromptRequest.ScreenText -match '(?m)^Component\s+Name\s+Installed\s+Available\s+Repository\s+Status\s*$' -and
            $PromptRequest.ScreenText -match '(?m)^Plugin\s+ExamplePlugin\s+1\.0\.0\s+2\.0\.0\s+Feed\s+Available\s*$' -and
            $PromptRequest.ScreenText -match '(?m)^Plugin\s+BlockedPlugin\s+1\.0\.0\s+-\s+Feed\s+Blocked\s*$'
        }
    }

    It 'renders each checkbox as a single line with the repository in parentheses' {
        $item = [pscustomobject]@{
            Kind = 'Plugin'; State = [pscustomobject]@{
                Status = 'Available'; Name = 'ExamplePlugin'; Installed = '1.0.0'; Available = '2.0.0'; Repository = 'Feed'; Message = ''
            }
        }
        Mock Read-GerberCheckboxMenuPrompt {
            [pscustomobject]@{ SelectedValueList = @() }
        }
        $null = Read-GerberUpdateItemSelection -ItemList @($item)
        Should -Invoke Read-GerberCheckboxMenuPrompt -ParameterFilter {
            $PromptRequest.ItemList[0].Label -ceq 'ExamplePlugin  1.0.0 -> 2.0.0  (Feed)' -and -not $PromptRequest.ItemList[0].Description
        }
    }

    It 'does not open a checkbox when there are no available candidates' {
        Mock Read-GerberCheckboxMenuPrompt {
        }
        @(Read-GerberUpdateItemSelection -ItemList @()).Count | Should -Be 0
        Should -Invoke Read-GerberCheckboxMenuPrompt -Times 0
    }
}
