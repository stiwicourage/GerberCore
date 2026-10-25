BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberCollectionCount' {
    It 'returns zero for null input' {
        $result = Get-GerberCollectionCount -InputObject $null

        $result | Should -Be 0
    }

    It 'returns one for a scalar input' {
        $result = Get-GerberCollectionCount -InputObject 'item'

        $result | Should -Be 1
    }

    It 'returns the element count for an array input' {
        $result = Get-GerberCollectionCount -InputObject @('a', 'b', 'c')

        $result | Should -Be 3
    }

    It 'returns one for a non-collection object' {
        $result = Get-GerberCollectionCount -InputObject ([pscustomobject]@{ Name = 'item' })

        $result | Should -Be 1
    }
}
