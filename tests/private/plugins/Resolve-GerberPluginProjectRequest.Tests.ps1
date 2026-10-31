BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Resolve-GerberPluginProjectRequest' -Tag 'PluginCreate' {
    It 'fixes the Gerber prefix and defaults the destination parent to cwd' {
        $request = Resolve-GerberPluginProjectRequest -InputMap @{
            Suffix = 'MyCompany'; Description = 'My tools'; Namespace = 'mycompany'
        }
        $request.Name | Should -Be 'Gerber.MyCompany'
        $request.ParentPath | Should -Be (Get-Location).ProviderPath
        $request.Destination | Should -Be (Join-Path (Get-Location).ProviderPath 'Gerber.MyCompany')
    }

    It 'accepts a custom existing parent' {
        $request = Resolve-GerberPluginProjectRequest -InputMap @{
            Suffix = 'Example'; Description = 'Example'; Namespace = 'example'; ParentPath = $TestDrive
        }
        $request.Destination | Should -Be (Join-Path $TestDrive 'Gerber.Example')
    }

    It 'rejects invalid suffix <Suffix>' -ForEach @(
        @{ Suffix = '../Escape' }, @{ Suffix = 'Gerber.Example' }, @{ Suffix = '' },
        @{ Suffix = 'bad/name' }, @{ Suffix = 'bad\name' }, @{ Suffix = 'bad name' }
    ) {
        {
            Resolve-GerberPluginProjectRequest -InputMap @{
                Suffix = $Suffix; Description = 'Example'; Namespace = 'example'
            }
        } | Should -Throw '*suffix*'
    }

    It 'rejects invalid or occupied namespace <Namespace>' -ForEach @(
        @{ Namespace = 'plugins' }, @{ Namespace = 'tools' }, @{ Namespace = 'MyCompany' },
        @{ Namespace = '../bad' }, @{ Namespace = 'two words' }, @{ Namespace = '' }
    ) {
        {
            Resolve-GerberPluginProjectRequest -InputMap @{
                Suffix = 'Example'; Description = 'Example'; Namespace = $Namespace
            }
        } | Should -Throw '*namespace*'
    }

    It 'never overwrites an existing destination' {
        $null = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'Gerber.Example')
        {
            Resolve-GerberPluginProjectRequest -InputMap @{
                Suffix = 'Example'; Description = 'Example'; Namespace = 'example'; ParentPath = $TestDrive
            }
        } | Should -Throw '*already exists*'
    }

    It 'rejects traversal and missing destination parents' -ForEach @(
        @{ Parent = '..' }, @{ Parent = 'missing-parent' }
    ) {
        {
            Resolve-GerberPluginProjectRequest -InputMap @{
                Suffix = 'Example'; Description = 'Example'; Namespace = 'example'; ParentPath = $Parent
            }
        } | Should -Throw '*parent*'
    }

    Context 'repository-aware input map' -Tag 'PluginCreateRepository' {
        BeforeEach {
            $parent = Join-Path $TestDrive ([System.IO.Path]::GetRandomFileName())
            $null = New-Item -ItemType Directory -Path $parent
            $script:inputMap = @{
                Suffix = 'Example'; Description = 'Example'; Namespace = 'example'; ParentPath = $parent
            }
        }

        It 'preserves explicit <Label> while resolving the destination' -ForEach @(
            @{ Label = 'known URI'; Uri = 'https://packages.example.org/feed' }
            @{ Label = 'creation placeholder'; Uri = 'REPLACE_WITH_REPOSITORY_URI' }
        ) {
            $script:inputMap.RepositoryUri = $Uri
            $request = Resolve-GerberPluginProjectRequest -InputMap $script:inputMap
            $request.RepositoryUri | Should -BeExactly $Uri
            $request.Destination | Should -Be (Join-Path $parent 'Gerber.Example')
        }

        It 'rejects invalid explicit URI <Uri> rather than silently choosing PSGallery' -ForEach @(
            @{ Uri = '' }, @{ Uri = $null }, @{ Uri = 'relative-feed' }
            @{ Uri = 'https://user:password@example.org/feed' }
            @{ Uri = 'https://example.org/feed?token=secret' }, @{ Uri = 'https://example.org/feed#fragment' }
        ) {
            $script:inputMap.RepositoryUri = $Uri
            {
                Resolve-GerberPluginProjectRequest -InputMap $script:inputMap
            } | Should -Throw '*absolute repository URI*'
        }

        It 'requires the fixed fields even when the input map is incomplete' {
            $script:inputMap.Remove('Suffix')
            {
                Resolve-GerberPluginProjectRequest -InputMap $script:inputMap
            } | Should -Throw '*suffix*'
        }
    }
}
