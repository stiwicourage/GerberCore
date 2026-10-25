BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberPluginCredentialIdentifier' {
    It 'separates identical credential names by plugin manifest GUID' {
        $first = Get-GerberPluginCredentialIdentifier `
            -PluginId ([guid]'11111111-1111-1111-1111-111111111111') `
            -PathSegmentList @('confluence', 'api token')
        $second = Get-GerberPluginCredentialIdentifier `
            -PluginId ([guid]'22222222-2222-2222-2222-222222222222') `
            -PathSegmentList @('confluence', 'api token')

        $first | Should -Be 'gerber:plugin:11111111-1111-1111-1111-111111111111:confluence:api%20token'
        $second | Should -Be 'gerber:plugin:22222222-2222-2222-2222-222222222222:confluence:api%20token'
        $first | Should -Not -Be $second
    }
}
