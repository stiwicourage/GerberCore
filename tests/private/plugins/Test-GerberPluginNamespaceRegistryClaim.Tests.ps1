BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
    $script:FirstGuid = '6996218c-58d0-48ce-b6cc-38d06149230a'
    $script:SecondGuid = '977537c5-b7f5-4f2f-9dd4-5ec0e28d2618'
}

Describe 'Test-GerberPluginNamespaceRegistryClaim' {
    BeforeEach {
        $script:claimList = @(
            [pscustomobject]@{ Guid = $script:SecondGuid; Name = 'Gerber.ADO'; Namespace = 'ado'; FirstPublished = [datetime]'2026-03-01' }
            [pscustomobject]@{ Guid = $script:FirstGuid; Name = 'Gerber.AzureDevOps'; Namespace = 'ado'; FirstPublished = [datetime]'2026-01-15' }
            [pscustomobject]@{ Guid = '11111111-2222-3333-4444-555555555555'; Name = 'Gerber.Other'; Namespace = 'other'; FirstPublished = [datetime]'2025-01-01' }
        )
    }

    It 'reports the plugin as the owner when it published the namespace first' {
        $result = Test-GerberPluginNamespaceRegistryClaim -Guid $script:FirstGuid -Namespace 'ado' -ClaimList $script:claimList

        $result.Status | Should -Be 'Owner'
        $result.Owner.Guid | Should -Be $script:FirstGuid
    }

    It 'reports a conflict naming the earliest publisher when another plugin published first' {
        $result = Test-GerberPluginNamespaceRegistryClaim -Guid $script:SecondGuid -Namespace 'ado' -ClaimList $script:claimList

        $result.Status | Should -Be 'Conflict'
        $result.Owner.Name | Should -Be 'Gerber.AzureDevOps'
    }

    It 'matches GUIDs and namespaces case-insensitively' {
        $result = Test-GerberPluginNamespaceRegistryClaim -Guid $script:FirstGuid.ToUpperInvariant() -Namespace 'ADO' -ClaimList $script:claimList

        $result.Status | Should -Be 'Owner'
    }

    It 'reports the namespace as available when nobody published it' {
        $result = Test-GerberPluginNamespaceRegistryClaim -Guid $script:FirstGuid -Namespace 'unclaimed' -ClaimList $script:claimList

        $result.Status | Should -Be 'Available'
        $result.Owner | Should -BeNullOrEmpty
    }

    It 'treats an empty claim list as available' {
        $result = Test-GerberPluginNamespaceRegistryClaim -Guid $script:FirstGuid -Namespace 'ado' -ClaimList @()

        $result.Status | Should -Be 'Available'
    }

    It 'breaks a publication-date tie deterministically by GUID, independent of list order' {
        $tieList = @(
            [pscustomobject]@{ Guid = $script:SecondGuid; Name = 'B'; Namespace = 'ado'; FirstPublished = [datetime]'2026-01-15' }
            [pscustomobject]@{ Guid = $script:FirstGuid; Name = 'A'; Namespace = 'ado'; FirstPublished = [datetime]'2026-01-15' }
        )

        (Test-GerberPluginNamespaceRegistryClaim -Guid $script:SecondGuid -Namespace 'ado' -ClaimList $tieList).Owner.Guid |
            Should -Be $script:FirstGuid
        (Test-GerberPluginNamespaceRegistryClaim -Guid $script:SecondGuid -Namespace 'ado' -ClaimList @($tieList[1], $tieList[0])).Owner.Guid |
            Should -Be $script:FirstGuid
    }

    It 'reports an unverified result, never success, when the claim list could not be read' {
        $result = Test-GerberPluginNamespaceRegistryClaim -Guid $script:FirstGuid -Namespace 'ado' -ClaimList $null -LookupFailure 'offline'

        $result.Status | Should -Be 'Unverified'
        $result.Reason | Should -Be 'offline'
    }
}
