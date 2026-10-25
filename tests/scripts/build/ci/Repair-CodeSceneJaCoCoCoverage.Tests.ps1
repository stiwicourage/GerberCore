BeforeAll {
    $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
    $script:scriptPath = Join-Path $repositoryRoot 'scripts/build/ci/Repair-CodeSceneJaCoCoCoverage.ps1'
}

Describe 'Repair-CodeSceneJaCoCoCoverage' -Tag 'BuildTooling' {
    It 'reduces sourcefile paths to file names and reports the normalization' {
        $path = Join-Path $TestDrive 'coverage.xml'
        Set-Content -LiteralPath $path -Value '<report><package><class sourcefilename="src/public/A.ps1" /><sourcefile name="src/public/A.ps1" /></package></report>'

        $output = & $script:scriptPath -Path $path 6>&1 | Out-String

        [xml]$result = Get-Content -LiteralPath $path -Raw
        $result.SelectSingleNode('//class').GetAttribute('sourcefilename') | Should -Be 'A.ps1'
        $result.SelectSingleNode('//sourcefile').GetAttribute('name') | Should -Be 'A.ps1'
        $output | Should -Match 'Normalized JaCoCo sourcefile paths'
    }

    It 'leaves already normalized files untouched' {
        $path = Join-Path $TestDrive 'normal.xml'
        $content = '<report><package><class sourcefilename="A.ps1" /><sourcefile name="A.ps1" /></package></report>'
        Set-Content -LiteralPath $path -Value $content -NoNewline

        $output = & $script:scriptPath -Path $path 6>&1 | Out-String

        (Get-Content -LiteralPath $path -Raw) | Should -Be $content
        $output | Should -Not -Match 'Normalized'
    }

    It 'fails when a coverage file does not exist' {
        { & $script:scriptPath -Path (Join-Path $TestDrive 'missing.xml') } | Should -Throw
    }
}
