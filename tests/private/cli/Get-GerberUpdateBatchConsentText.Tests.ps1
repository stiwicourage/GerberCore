BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $source = "$root/src/private/cli/Get-GerberUpdateBatchConsentText.ps1"
    if (Test-Path $source) {
        . $source
    }
    . "$root/src/private/cli/Format-GerberUpdateItemOverview.ps1"
}

Describe 'Get-GerberUpdateBatchConsentText' -Tag 'G4A9UI' {
    It 'lists one compact line per component with versions, once-only source and scope, and the Core auto-add reason' {
        $plan = [pscustomobject]@{
            Scope = 'CurrentUser'; RepositoryUri = 'https://example.test/v2'
            RequiresRepositoryTrust = $true; RequiresLicenseAcceptance = $true
        }
        $core = [pscustomobject]@{
            Name = 'Gerber'; Installed = '1.0.0-preview'; Available = '2.0.0-preview.12'; Repository = 'PSGallery'; Status = 'Available'; Plan = $plan; Message = ''
        }
        $plugin = [pscustomobject]@{
            Name = 'Gerber.Plugin'; Installed = '0.1.0'; Available = '0.2.0'; Repository = 'PSGallery'; Status = 'Available'; Plan = $plan; Message = ''
        }
        $items = @(
            [pscustomobject]@{ Kind = 'Core'; State = $core; AutoAdded = $true; MinimumCore = $null }
            [pscustomobject]@{ Kind = 'Plugin'; State = $plugin; AutoAdded = $false; MinimumCore = '2.0.0-preview.12' }
        )
        $text = Get-GerberUpdateBatchConsentText -Batch ([pscustomobject]@{ Items = $items })
        $text | Should -Match '(?m)^\s*Gerber\s+1\.0\.0-preview -> 2\.0\.0-preview\.12\s+\(added: required by Gerber\.Plugin\)$'
        $text | Should -Match '(?m)^\s*Gerber\.Plugin\s+0\.1\.0 -> 0\.2\.0\s+\(requires Core 2\.0\.0-preview\.12\)$'
        ([regex]::Matches($text, 'https://example.test/v2')).Count | Should -Be 1
        $text | Should -Match 'Scope: CurrentUser'
        $text | Should -Match 'not hot reload'
        $text | Should -Not -Match 'trust|license|Cancel is the default'
    }

    It 'retains blocked item reasons in the final preview without inventing scope or versions' {
        $state = [pscustomobject]@{
            Name = 'BlockedPlugin'; Installed = '1.0.0'; Available = '2.0.0'; Repository = 'Private'; Status = 'Blocked'; Plan = $null; Message = 'Required Core is unavailable.'
        }
        $item = [pscustomobject]@{
            Kind = 'Plugin'; State = $state; AutoAdded = $false; MinimumCore = '3.0.0'
        }
        Get-GerberUpdateBatchConsentText -Batch ([pscustomobject]@{
            Items = @($item)
        }) | Should -Match '(?m)^\s*BlockedPlugin\s+Blocked: Required Core is unavailable\.$'
    }
}
