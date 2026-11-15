BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Invoke-GerberPluginsInstallCommand' {
    BeforeEach {
        $script:verdict = [pscustomobject]@{ Status = 'Available'; Owner = $null; Reason = $null; Namespace = 'ado' }
        Mock Read-GerberCommand { 'Gerber.AzureDevOps' }
        Mock Get-GerberGalleryNamespaceVerdict { $script:verdict }
        Mock Read-GerberConfirmationPrompt { $true }
        Mock Install-GerberGalleryPlugin {}
        Mock Show-GerberTextBlock {}
        Mock Wait-GerberContinue {}
    }

    It 'installs after the registry check and confirmation, then points to /plugins enable' {
        Invoke-GerberPluginsInstallCommand

        Should -Invoke Get-GerberGalleryNamespaceVerdict -Times 1 -ParameterFilter { $Name -eq 'Gerber.AzureDevOps' }
        Should -Invoke Install-GerberGalleryPlugin -Times 1 -ParameterFilter { $Name -eq 'Gerber.AzureDevOps' }
        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter { $Text -like '*/plugins enable*' }
    }

    It 'refuses to install when another plugin owns the namespace and names the owner' {
        $script:verdict = [pscustomobject]@{
            Status = 'Conflict'; Reason = $null; Namespace = 'ado'
            Owner = [pscustomobject]@{ Name = 'Gerber.First'; FirstPublished = [datetime]'2026-01-01' }
        }

        Invoke-GerberPluginsInstallCommand

        Should -Invoke Install-GerberGalleryPlugin -Times 0
        Should -Invoke Read-GerberConfirmationPrompt -Times 0
        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter { $Text -like '*Gerber.First*' -and $Text -like '*/ado*' }
    }

    It 'shows an unverified result and installs only after explicit confirmation' {
        $script:verdict = [pscustomobject]@{ Status = 'Unverified'; Owner = $null; Reason = 'offline'; Namespace = $null }

        Invoke-GerberPluginsInstallCommand

        Should -Invoke Read-GerberConfirmationPrompt -Times 1 -ParameterFilter { $ScreenText -like '*unverified*offline*' }
        Should -Invoke Install-GerberGalleryPlugin -Times 1
    }

    It 'does not install when the confirmation is declined' {
        Mock Read-GerberConfirmationPrompt { $false }

        Invoke-GerberPluginsInstallCommand

        Should -Invoke Install-GerberGalleryPlugin -Times 0
    }

    It 'returns quietly when the name prompt is cancelled with Esc' {
        Mock Read-GerberCommand { throw (Get-GerberMenuEscapeException) }

        { Invoke-GerberPluginsInstallCommand } | Should -Not -Throw

        Should -Invoke Get-GerberGalleryNamespaceVerdict -Times 0
        Should -Invoke Install-GerberGalleryPlugin -Times 0
    }

    It 'returns quietly when no name is entered' {
        Mock Read-GerberCommand { '' }

        Invoke-GerberPluginsInstallCommand

        Should -Invoke Get-GerberGalleryNamespaceVerdict -Times 0
    }

    It 'asks again when the module name is not valid' {
        $script:answers = [System.Collections.Queue]::new(@('bad name!', 'Gerber.Ok'))
        Mock Read-GerberCommand { $script:answers.Dequeue() }

        Invoke-GerberPluginsInstallCommand

        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter { $Text -like '*not a valid module name*' }
        Should -Invoke Install-GerberGalleryPlugin -Times 1 -ParameterFilter { $Name -eq 'Gerber.Ok' }
    }

    It 'reports an installation failure with Gerber-owned text instead of throwing' {
        Mock Install-GerberGalleryPlugin { throw 'boom' }

        { Invoke-GerberPluginsInstallCommand } | Should -Not -Throw

        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter { $Text -like '*could not install*boom*' }
    }

    It 'rejects extra arguments' {
        { Invoke-GerberPluginsInstallCommand -Command ([pscustomobject]@{ Arguments = @('x') }) } | Should -Throw
    }
}

Describe 'Get-GerberGalleryNamespaceVerdict' {
    BeforeEach {
        $script:claims = @(
            [pscustomobject]@{ Guid = 'Gerber.First'; Name = 'Gerber.First'; Namespace = 'ado'; FirstPublished = [datetime]'2026-01-01' }
            [pscustomobject]@{ Guid = 'Gerber.Second'; Name = 'Gerber.Second'; Namespace = 'ado'; FirstPublished = [datetime]'2026-02-01' }
        )
        Mock Get-GerberGalleryPluginClaimList { [pscustomobject]@{ Namespace = 'ado'; ClaimList = $script:claims } }
    }

    It 'reports the earliest publisher as owner' {
        (Get-GerberGalleryNamespaceVerdict -Name 'Gerber.First').Status | Should -Be 'Owner'
    }

    It 'reports a conflict for a later publisher' {
        $result = Get-GerberGalleryNamespaceVerdict -Name 'Gerber.Second'

        $result.Status | Should -Be 'Conflict'
        $result.Owner.Name | Should -Be 'Gerber.First'
        $result.Namespace | Should -Be 'ado'
    }

    It 'reports unverified when the lookup throws' {
        Mock Get-GerberGalleryPluginClaimList { throw 'offline' }

        $result = Get-GerberGalleryNamespaceVerdict -Name 'Gerber.First'

        $result.Status | Should -Be 'Unverified'
        $result.Reason | Should -Match 'offline'
    }

    It 'reports unverified when the module publishes no namespace' {
        Mock Get-GerberGalleryPluginClaimList { [pscustomobject]@{ Namespace = $null; ClaimList = @() } }

        (Get-GerberGalleryNamespaceVerdict -Name 'Gerber.First').Status | Should -Be 'Unverified'
    }
}

Describe 'ConvertTo-GerberGalleryPluginClaimList' {
    It 'groups versions per module and uses the oldest publication date' {
        $resourceList = @(
            [pscustomobject]@{ Name = 'Gerber.A'; PublishedDate = [datetime]'2026-03-01' }
            [pscustomobject]@{ Name = 'Gerber.A'; PublishedDate = [datetime]'2026-01-10' }
            [pscustomobject]@{ Name = 'Gerber.B'; PublishedDate = [datetime]'2026-02-01' }
        )

        $claimList = @(ConvertTo-GerberGalleryPluginClaimList -ResourceList $resourceList -Namespace 'ado')

        $claimList.Count | Should -Be 2
        ($claimList | Where-Object Name -eq 'Gerber.A').FirstPublished | Should -Be ([datetime]'2026-01-10')
        ($claimList | Where-Object Name -eq 'Gerber.A').Guid | Should -Be 'Gerber.A'
        ($claimList | Where-Object Name -eq 'Gerber.B').Namespace | Should -Be 'ado'
    }
}

Describe 'Get-GerberGalleryNamespaceFromTagList' {
    It 'reads the namespace from the GerberNamespace_ tag' {
        Get-GerberGalleryNamespaceFromTagList -TagList @('GerberPlugin', 'GerberNamespace_ado') | Should -Be 'ado'
    }

    It 'returns nothing when no namespace tag exists' {
        Get-GerberGalleryNamespaceFromTagList -TagList @('GerberPlugin') | Should -BeNullOrEmpty
    }
}
