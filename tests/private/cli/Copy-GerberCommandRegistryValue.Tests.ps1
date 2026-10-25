BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    . (Join-Path $root 'src/private/cli/Copy-GerberCommandRegistryValue.ps1')
}

Describe 'Copy-GerberCommandRegistryValue' -Tag 'PluginTransactions' {
    BeforeEach {
        $script:memo = [System.Collections.Generic.Dictionary[object, object]]::new([System.Collections.Generic.ReferenceEqualityComparer]::Instance)
    }

    Context 'Command catalog values' {
        It 'preserves scalar inline values and nulls' {
            Copy-GerberCommandRegistryValue -Value $null -Memo $script:memo | Should -BeNullOrEmpty
            Copy-GerberCommandRegistryValue -Value 'inline description' -Memo $script:memo | Should -Be 'inline description'
        }

        It 'clones mutable dictionaries once by reference rather than content' {
            $first = [ordered]@{ child = 'help' }
            $second = [ordered]@{ child = 'help' }
            $value = [ordered]@{ first = $first; alias = $first; second = $second }

            $copy = Copy-GerberCommandRegistryValue -Value $value -Memo $script:memo

            [object]::ReferenceEquals($copy.first, $copy.alias) | Should -BeTrue
            [object]::ReferenceEquals($copy.first, $copy.second) | Should -BeFalse
            $copy.first['new'] = 'new help'
            $first.Contains('new') | Should -BeFalse
        }

        It 'copies object-shaped catalog entries while preserving handler and metadata identity' {
            $handler = { return $true }
            $metadata = [pscustomobject]@{ Marker = 'same metadata' }
            $tags = @('one')
            $entry = [pscustomobject]@{
                Subcommands = [ordered]@{ inline = @{ Description = 'inline'; Subcommands = [ordered]@{}; Tags = $tags } }
                Handler = $handler; Metadata = $metadata
            }

            $copy = Copy-GerberCommandRegistryValue -Value $entry -Memo $script:memo

            [object]::ReferenceEquals($entry, $copy) | Should -BeFalse
            [object]::ReferenceEquals($copy.Handler, $handler) | Should -BeTrue
            [object]::ReferenceEquals($copy.Metadata, $metadata) | Should -BeTrue
            [object]::ReferenceEquals($copy.Subcommands.inline.Tags, $tags) | Should -BeTrue
            $copy.Subcommands.inline.Subcommands['child'] = 'help'
            $entry.Subcommands.inline.Subcommands.Count | Should -Be 0
        }
    }
}
