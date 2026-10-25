BeforeAll {
    . (Join-Path $PSScriptRoot '../../../src/private/plugins/Get-GerberPluginBoundaryResult.ps1')
    . (Join-Path $PSScriptRoot '../../../src/private/plugins/Get-GerberBoundaryDiagnostic.ps1')
    . (Join-Path $PSScriptRoot '../../../src/private/plugins/Get-GerberPluginUsingDiagnostic.ps1')
}

Describe 'Get-GerberPluginBoundaryResult' -Tag 'PluginBoundary' {
    It 'returns an explicit valid empty-source result and the supplied public inventory' {
        $null = New-Item -ItemType Directory "$TestDrive/src" -Force
        $contract = [pscustomobject]@{ PublicApi = @{ UI = @('Example') }; PrivateCommands = @{} }
        $result = Get-GerberPluginBoundaryResult -Path $TestDrive -Contract $contract
        $result.IsValid | Should -BeTrue
        $result.FileCount | Should -Be 0
        $result.Diagnostics.Count | Should -Be 0
        $result.PublicApi.UI | Should -Contain 'Example'
    }
}
