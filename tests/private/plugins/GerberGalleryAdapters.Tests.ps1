BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberGalleryPluginClaimList' {
    It 'fails when the module is not on the Gallery' {
        Mock Find-PSResource { @() }

        { Get-GerberGalleryPluginClaimList -Name 'Gerber.Missing' } | Should -Throw "*was not found on PowerShell Gallery*"
    }

    It 'returns no claims when the module publishes no namespace tag' {
        Mock Find-PSResource { [pscustomobject]@{ Name = 'Gerber.Plain'; Tags = @('PSModule') } }

        $result = Get-GerberGalleryPluginClaimList -Name 'Gerber.Plain'

        $result.Namespace | Should -BeNullOrEmpty
        @($result.ClaimList).Count | Should -Be 0
    }

    It 'returns the claim of every module that publishes the namespace tag with its first publication date' {
        $first = [datetime]'2026-01-01'
        $second = [datetime]'2026-03-01'
        Mock Find-PSResource {
            if ($Tag) { return @([pscustomobject]@{ Name = 'Gerber.Other' }) }
            if ($Name -eq 'Gerber.Mine') {
                return @(
                    [pscustomobject]@{ Name = 'Gerber.Mine'; Tags = @('GerberNamespace_ado'); PublishedDate = $second }
                    [pscustomobject]@{ Name = 'Gerber.Mine'; Tags = @('GerberNamespace_ado'); PublishedDate = [datetime]'2026-04-01' }
                )
            }
            return @([pscustomobject]@{ Name = 'Gerber.Other'; PublishedDate = $first })
        }

        $result = Get-GerberGalleryPluginClaimList -Name 'Gerber.Mine'

        $result.Namespace | Should -Be 'ado'
        $claimList = @($result.ClaimList)
        @($claimList.Name | Sort-Object) | Should -Be @('Gerber.Mine', 'Gerber.Other')
        ($claimList | Where-Object Name -EQ 'Gerber.Other').FirstPublished | Should -Be $first
        ($claimList | Where-Object Name -EQ 'Gerber.Mine').FirstPublished | Should -Be $second
    }
}

Describe 'Install-GerberGalleryPlugin' {
    It 'installs from PowerShell Gallery for the current user without a second trust prompt' {
        Mock Install-PSResource {}

        Install-GerberGalleryPlugin -Name 'Gerber.Mine'

        Should -Invoke Install-PSResource -Times 1 -ParameterFilter {
            $Name -eq 'Gerber.Mine' -and $Repository -eq 'PSGallery' -and $Scope -eq 'CurrentUser' -and $TrustRepository
        }
    }
}
