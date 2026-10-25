# Cross-cutting contract: exercise the installed PMU's selection and decision code, not a Gerber comparator.
BeforeAll {
    Import-Module PSModuleUpdate
    $script:pmu = Get-Module PSModuleUpdate
}

Describe 'Core PMU stable channel contract' -Tag 'G4A7' {
    It 'rejects a repointed named PSGallery registration using the canonical URI policy' {
        Import-Module Microsoft.PowerShell.PSResourceGet -RequiredVersion '1.2.0'
        Mock 'Microsoft.PowerShell.PSResourceGet\Get-PSResourceRepository' -ModuleName PSModuleUpdate {
            [pscustomobject]@{ Name = 'PSGallery'; Uri = [uri]'https://feed.invalid'; Trusted = $true; ApiVersion = 'v2' }
        }
        $id = & $pmu {
            try { Get-RepositorySnapshot 'PSGallery' ([uri]'https://www.powershellgallery.com/api/v2') }
            catch { ($_.FullyQualifiedErrorId -split ',')[0] }
        }
        $id | Should -BeExactly 'PMU.RepositoryChanged'
    }

    It 'selects <target> for installed preview from <versions>' -ForEach @(
        @{ versions = @('0.1.0-preview', '0.1.0'); target = '0.1.0' }
        @{ versions = @('0.2.0-preview', '0.1.0'); target = '0.1.0' }
        @{ versions = @('0.2.0-preview', '0.2.0', '0.3.0-preview'); target = '0.2.0' }
    ) {
        $result = & $pmu {
            param($versions)
            $releases = @($versions | ForEach-Object { [pscustomobject]@{ Version = ConvertTo-CompleteModuleVersion $_ } })
            $target = Select-UpdateTarget $releases 'Stable'
            $installed = ConvertTo-CompleteModuleVersion '0.1.0-preview'
            $decision = Get-UpdateDecision ([pscustomobject]@{
                Target = $target; Installed = $installed; Active = [pscustomobject]@{ Version = $installed }
            })
            [pscustomobject]@{ Target = $target.Version.FullVersion; Disposition = $decision.Disposition }
        } $versions
        $result.Target | Should -BeExactly $target
        $result.Disposition | Should -BeExactly 'UpdateAvailable'
    }

    It 'reports no eligible package for preview-only or empty gallery results' -ForEach @(
        @{ versions = @('0.2.0-preview') }
        @{ versions = @() }
    ) {
        $errorId = & $pmu {
            param($versions)
            $releases = @($versions | ForEach-Object { [pscustomobject]@{ Version = ConvertTo-CompleteModuleVersion $_ } })
            try { Select-UpdateTarget $releases 'Stable' }
            catch { ($_.FullyQualifiedErrorId -split ',')[0] }
        } $versions
        $errorId | Should -BeExactly 'PMU.PackageNotFound'
    }
}
