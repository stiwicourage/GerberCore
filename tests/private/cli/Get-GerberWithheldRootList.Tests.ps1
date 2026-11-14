BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    . (Join-Path $root 'src/private/cli/Get-GerberWithheldRootList.ps1')
}

Describe 'Get-GerberWithheldRootList' -Tag 'G3B' {
    It 'returns an empty list for a source without withheld roots' {
        @(Get-GerberWithheldRootList -Source ([pscustomobject]@{})).Count | Should -Be 0
    }

    It 'copies entries and drops a root once fewer than two plugins remain' {
        $source = [pscustomobject]@{
            WithheldRootList = @(
                [pscustomobject]@{ Root = 'ado'; OwnerNameList = @('A', 'B', 'C') }
                [pscustomobject]@{ Root = 'git'; OwnerNameList = @('A', 'D') }
            )
        }

        $result = @(Get-GerberWithheldRootList -Source $source -WithoutOwner 'A')

        $result.Count | Should -Be 1
        $result[0].Root | Should -Be 'ado'
        $result[0].OwnerNameList | Should -Be @('B', 'C')
        @(Get-GerberWithheldRootList -Source $source).Count | Should -Be 2
    }
}
