# Child-process Nova validation spans the resource script, templates and Core
# registration. New-GerberPluginProject.Integration.Tests.ps1 proves success.
BeforeAll {
    $root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
    $validator = Join-Path $root 'src/resources/Test-GerberGeneratedProject.ps1'
    $null = $validator
}

Describe 'Test-GerberGeneratedProject' -Tag 'PluginCreate' {
    It 'returns a failing process status for an invalid generated project' {
        $project = @{
            ProjectName = 'Gerber.Invalid'; Description = 'Invalid'; Version = '0.1.0'
            Manifest = @{ Author = 'Example'; PowerShellHostVersion = '7.4'; GUID = '5ff12592-8333-40d1-b167-9f5902149843' }
            Pester = @{}
        }
        $project | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $TestDrive 'project.json')
        $output = & (Join-Path $PSHOME 'pwsh') -NoLogo -NoProfile -NonInteractive -File $validator -ProjectPath $TestDrive 2>&1
        $LASTEXITCODE | Should -Be 1
        ($output -join "`n") | Should -Match 'Invalid project.json'
    }
}
