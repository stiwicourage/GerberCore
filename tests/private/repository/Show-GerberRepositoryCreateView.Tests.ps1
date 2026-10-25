BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Show-GerberRepositoryCreateView' {
    It 'returns when Read-GerberRepositoryCreateProjectOrNull returns null' {
        Mock Show-GerberRepositoryCreateHeader {}
        Mock Read-GerberRepositoryCreateProjectOrNull { $null }
        Mock Read-GerberRepositoryCreateTemplateOrNull {}

        Show-GerberRepositoryCreateView -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Read-GerberRepositoryCreateProjectOrNull -Times 1
        Should -Invoke Read-GerberRepositoryCreateTemplateOrNull -Times 0
    }

    It 'breaks inner loop and re-prompts project when Read-GerberRepositoryCreateTemplateOrNull returns null' {
        Mock Show-GerberRepositoryCreateHeader {}
        $script:projectCallCount = 0
        Mock Read-GerberRepositoryCreateProjectOrNull {
            $script:projectCallCount++
            if ($script:projectCallCount -eq 1) {
                [pscustomobject]@{ Id = 'p1'; Name = 'Proj' }
            } else {
                $null
            }
        }
        Mock Read-GerberRepositoryCreateTemplateOrNull { $null }

        Show-GerberRepositoryCreateView -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Read-GerberRepositoryCreateProjectOrNull -Times 2
        Should -Invoke Read-GerberRepositoryCreateTemplateOrNull -Times 1
    }

    It 'calls the generic template flow when <TemplateName> is selected' -ForEach @(
        @{ TemplateId = '1'; TemplateName = 'Template_NuGet' }
        @{ TemplateId = '2'; TemplateName = 'Template_Domain' }
        @{ TemplateId = '3'; TemplateName = 'Template_Java' }
    ) {
        Mock Show-GerberRepositoryCreateHeader {}
        $script:projectCallCount = 0
        Mock Read-GerberRepositoryCreateProjectOrNull {
            $script:projectCallCount++
            if ($script:projectCallCount -eq 1) {
                [pscustomobject]@{ Id = 'p1'; Name = 'Proj' }
            } else {
                $null
            }
        }
        $script:templateCallCount = 0
        Mock Read-GerberRepositoryCreateTemplateOrNull {
            $script:templateCallCount++
            if ($script:templateCallCount -eq 1) {
                [pscustomobject]@{ Id = $TemplateId; Name = $TemplateName }
            } else {
                $null
            }
        }
        Mock Invoke-GerberRepositoryCreateFromTemplateFlow {}

        Show-GerberRepositoryCreateView -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Invoke-GerberRepositoryCreateFromTemplateFlow -Times 1 `
            -ParameterFilter { $TemplateSelection.Name -eq $TemplateName }
    }

    It 'ignores any Arguments passed to the command and runs the interactive flow' {
        Mock Show-GerberRepositoryCreateHeader {}
        Mock Read-GerberRepositoryCreateProjectOrNull { $null }

        Show-GerberRepositoryCreateView -Command ([pscustomobject]@{ Arguments = @('nuget') })

        Should -Invoke Read-GerberRepositoryCreateProjectOrNull -Times 1
    }
}

Describe 'Invoke-GerberRepositoryCreateTemplateAction' {
    It 'routes <TemplateName> to the generic template flow and returns its result' -ForEach @(
        @{ TemplateName = 'Template_NuGet'; Result = $false }
        @{ TemplateName = 'Template_Domain'; Result = $true }
        @{ TemplateName = 'Template_Java'; Result = $true }
    ) {
        Mock Invoke-GerberRepositoryCreateFromTemplateFlow { $Result }

        $result = Invoke-GerberRepositoryCreateTemplateAction `
            -ProjectSelection ([pscustomobject]@{ Id = 'p1'; Name = 'Proj' }) `
            -TemplateSelection ([pscustomobject]@{ Name = $TemplateName })

        Should -Invoke Invoke-GerberRepositoryCreateFromTemplateFlow -Times 1 `
            -ParameterFilter { $TemplateSelection.Name -eq $TemplateName }
        $result | Should -Be $Result
    }
}

Describe 'Read-GerberRepositoryCreateTemplateOrNull' {
    It 'shows all templates without implementation labels and returns Template_NuGet when selected' {
        Mock Get-GerberAdoConfiguration { [pscustomobject]@{ CredentialIdentifier = 'gerber:ado:example:pat' } }
        Mock Resolve-GerberAdoPat { 'pat' }
        Mock Get-GerberAdoRepositoryTemplateList {
            @(
                [pscustomobject]@{ Id = '123'; Name = 'Template_NuGet' }
                [pscustomobject]@{ Id = '456'; Name = 'Template_Other' }
            )
        }
        Mock Convert-GerberListToNumberedMenuItemList {
            @(
                [pscustomobject]@{ Number = 1; Label = 'Template_NuGet'; Value = 'Template_NuGet'; PreviewText = '' }
                [pscustomobject]@{ Number = 2; Label = 'Template_Other'; Value = 'Template_Other'; PreviewText = '' }
            )
        }
        Mock Read-GerberNumberedMenuPrompt { 'Template_NuGet' }

        $result = Read-GerberRepositoryCreateTemplateOrNull -ProjectSelection ([pscustomobject]@{ Id = 'p1'; Name = 'TestProj' })

        $result.Name | Should -Be 'Template_NuGet'
        Should -Invoke Convert-GerberListToNumberedMenuItemList -Times 1
    }

    It 'does not append not-yet-implemented labels to templates' {
        $script:capturedItemList = $null
        Mock Get-GerberAdoConfiguration { [pscustomobject]@{ CredentialIdentifier = 'gerber:ado:example:pat' } }
        Mock Resolve-GerberAdoPat { 'pat' }
        Mock Get-GerberAdoRepositoryTemplateList {
            @(
                [pscustomobject]@{ Id = '123'; Name = 'Template_Domain' }
                [pscustomobject]@{ Id = '456'; Name = 'Template_Java' }
            )
        }
        Mock Convert-GerberListToNumberedMenuItemList {
            $script:capturedItemList = $ItemList
            @()
        }
        Mock Read-GerberNumberedMenuPrompt { throw (Get-GerberMenuEscapeException) }

        $null = Read-GerberRepositoryCreateTemplateOrNull -ProjectSelection ([pscustomobject]@{ Id = 'p1'; Name = 'TestProj' })

        $script:capturedItemList.Label | Should -Be @('Template_Domain', 'Template_Java')
    }

    It 'returns null and shows error when no templates exist' {
        Mock Get-GerberAdoConfiguration { [pscustomobject]@{ CredentialIdentifier = 'gerber:ado:example:pat' } }
        Mock Resolve-GerberAdoPat { 'pat' }
        Mock Get-GerberAdoRepositoryTemplateList { @() }
        Mock Show-GerberMenuError {}

        $result = Read-GerberRepositoryCreateTemplateOrNull -ProjectSelection ([pscustomobject]@{ Id = 'p1'; Name = 'TestProj' })

        $result | Should -BeNull
        Should -Invoke Show-GerberMenuError -Times 1 -ParameterFilter { $Message -like '*No template repositories found*' }
    }

    It 'returns null when Escape is pressed' {
        Mock Get-GerberAdoConfiguration { [pscustomobject]@{ CredentialIdentifier = 'gerber:ado:example:pat' } }
        Mock Resolve-GerberAdoPat { 'pat' }
        Mock Get-GerberAdoRepositoryTemplateList {
            @([pscustomobject]@{ Id = '123'; Name = 'Template_NuGet' })
        }
        Mock Convert-GerberListToNumberedMenuItemList { @() }
        Mock Read-GerberNumberedMenuPrompt { throw (Get-GerberMenuEscapeException) }

        $result = Read-GerberRepositoryCreateTemplateOrNull -ProjectSelection ([pscustomobject]@{ Id = 'p1'; Name = 'TestProj' })

        $result | Should -BeNull
    }
}

Describe 'Read-GerberRepositoryCreateProjectOrNull' {
    It 'returns selected project when no exception is thrown' {
        Mock Get-GerberAdoConfiguration { [pscustomobject]@{ CredentialIdentifier = 'gerber:ado:example:pat' } }
        Mock Resolve-GerberAdoPat { 'pat' }
        Mock Get-GerberAdoProjectList { @([pscustomobject]@{ Id = '1'; Name = 'TestProj' }) }
        Mock Convert-GerberListToNumberedMenuItemList { @([pscustomobject]@{ Number = 1; Label = 'TestProj'; Value = 'TestProj'; PreviewText = '' }) }
        Mock Read-GerberNumberedMenuPrompt { 'TestProj' }

        $result = Read-GerberRepositoryCreateProjectOrNull

        $result.Name | Should -Be 'TestProj'
    }

    It 'returns null when Escape is pressed' {
        Mock Get-GerberAdoConfiguration { [pscustomobject]@{ CredentialIdentifier = 'gerber:ado:example:pat' } }
        Mock Resolve-GerberAdoPat { 'pat' }
        Mock Get-GerberAdoProjectList { @() }
        Mock Convert-GerberListToNumberedMenuItemList { @() }
        Mock Read-GerberNumberedMenuPrompt { throw (Get-GerberMenuEscapeException) }

        $result = Read-GerberRepositoryCreateProjectOrNull

        $result | Should -BeNull
    }
}

Describe 'Show-GerberRepositoryCreateHeader' {
    It 'clears the host and writes the repository create route header' {
        Mock Start-GerberScreen {}
        Mock Write-GerberScreenLine {}

        Show-GerberRepositoryCreateHeader

        Should -Invoke Start-GerberScreen -Times 1 -ParameterFilter { $Name -eq '/repository create' }
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq '/repository create' }
        Should -Invoke Write-GerberScreenLine -Times 2
    }
}
