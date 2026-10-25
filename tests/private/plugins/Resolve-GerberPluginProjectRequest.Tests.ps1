BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Resolve-GerberPluginProjectRequest' -Tag 'PluginCreate' {
    It 'fixes the Gerber prefix and defaults the destination parent to cwd' {
        $request = Resolve-GerberPluginProjectRequest -Suffix 'MyCompany' -Description 'My tools' -Namespace 'mycompany'
        $request.Name | Should -Be 'Gerber.MyCompany'
        $request.ParentPath | Should -Be (Get-Location).ProviderPath
        $request.Destination | Should -Be (Join-Path (Get-Location).ProviderPath 'Gerber.MyCompany')
    }

    It 'accepts a custom existing parent' {
        $request = Resolve-GerberPluginProjectRequest -Suffix 'Example' -Description 'Example' -Namespace 'example' -ParentPath $TestDrive
        $request.Destination | Should -Be (Join-Path $TestDrive 'Gerber.Example')
    }

    It 'rejects invalid suffix <Suffix>' -ForEach @(
        @{ Suffix = '../Escape' }, @{ Suffix = 'Gerber.Example' }, @{ Suffix = '' },
        @{ Suffix = 'bad/name' }, @{ Suffix = 'bad\name' }, @{ Suffix = 'bad name' }
    ) {
        { Resolve-GerberPluginProjectRequest -Suffix $Suffix -Description 'Example' -Namespace 'example' } | Should -Throw '*suffix*'
    }

    It 'rejects invalid or occupied namespace <Namespace>' -ForEach @(
        @{ Namespace = 'plugins' }, @{ Namespace = 'tools' }, @{ Namespace = 'MyCompany' },
        @{ Namespace = '../bad' }, @{ Namespace = 'two words' }, @{ Namespace = '' }
    ) {
        { Resolve-GerberPluginProjectRequest -Suffix 'Example' -Description 'Example' -Namespace $Namespace } | Should -Throw '*namespace*'
    }

    It 'never overwrites an existing destination' {
        $null = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'Gerber.Example')
        { Resolve-GerberPluginProjectRequest -Suffix 'Example' -Description 'Example' -Namespace 'example' -ParentPath $TestDrive } | Should -Throw '*already exists*'
    }

    It 'rejects traversal and missing destination parents' -ForEach @(
        @{ Parent = '..' }, @{ Parent = 'missing-parent' }
    ) {
        { Resolve-GerberPluginProjectRequest -Suffix 'Example' -Description 'Example' -Namespace 'example' -ParentPath $Parent } | Should -Throw '*parent*'
    }
}
