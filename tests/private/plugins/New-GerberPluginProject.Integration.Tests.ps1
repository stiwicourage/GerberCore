BeforeAll {
    $repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
    $coreManifest = Join-Path $repositoryRoot 'dist/Gerber/Gerber.psd1'
    $null = $coreManifest

    function Assert-GerberCreatedPluginLifecycle {
        param([pscustomobject]$Created, [string]$ConfigPath)

        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json -AsHashtable
        $config.plugins.approved | Should -Contain $Created.Guid
        $config.plugins.associated[$Created.Guid].enabled | Should -BeTrue
        $config.plugins.associated[$Created.Guid].name | Should -Be 'Gerber.MyCompany'
        $config.plugins.associated[$Created.Guid].version | Should -Be '0.1.0'
        $inventory = & (Get-Module Gerber) { Get-GerberPluginInventory -PluginModulePathList @() }
        $entry = $inventory | Where-Object Guid -EQ $Created.Guid
        $entry.ApprovalStatus | Should -Be 'Approved'
        $entry.Name | Should -Be 'Gerber.MyCompany'
        $entry.Version | Should -Be '0.1.0'
        $entry.State | Should -Be 'Missing'
        $entry.IsAssociated | Should -BeTrue
        $entry.IsEnabled | Should -BeTrue
        $entry.IsDiscovered | Should -BeFalse
        $entry.Loaded | Should -BeFalse
        Get-Module Gerber.MyCompany | Should -BeNullOrEmpty
        Test-Path (Join-Path $Created.Path 'dist/Gerber.MyCompany/Gerber.MyCompany.psd1') | Should -BeTrue
    }
}

Describe 'New-GerberPluginProject isolated lifecycle integration' -Tag 'PluginCreate' {
    It 'builds, tests, locally publishes and discovers the approved GUID on fresh startup' {
        $originalConfig = $env:GERBER_CONFIG_PATH
        $env:GERBER_CONFIG_PATH = Join-Path $TestDrive 'config.json'
        try {
            Import-Module $coreManifest -Force
            $created = & (Get-Module Gerber) {
                param($Parent)
                Clear-GerberCommandRegistry
                $null = Initialize-GerberCommandRegistry -PluginModulePathList @()
                $request = Resolve-GerberPluginProjectRequest -Suffix MyCompany -Description 'Isolated hello' -Namespace mycompany -ParentPath $Parent
                New-GerberPluginProject -Request $request
            } $TestDrive
            Assert-GerberCreatedPluginLifecycle -Created $created -ConfigPath $env:GERBER_CONFIG_PATH
            $boundaryOutput = & (Join-Path $PSHOME 'pwsh') -NoLogo -NoProfile -NonInteractive -Command {
                param($Core, $Project)
                $coreModuleRoot = Split-Path -Parent (Split-Path -Parent $Core)
                $env:PSModulePath = $coreModuleRoot + [System.IO.Path]::PathSeparator + $env:PSModulePath
                Import-Module $Core -Force
                & (Join-Path $Project 'scripts/Test-PluginBoundary.ps1')
            } -args $coreManifest, $created.Path
            $LASTEXITCODE | Should -Be 0
            ($boundaryOutput -join "`n") | Should -Match 'boundary: passed'
            $moduleRoot = Join-Path $TestDrive 'modules'
            $publishScript = Join-Path $repositoryRoot 'tests/TestHelpers/Publish-GerberPluginTestProject.ps1'
            & (Join-Path $PSHOME 'pwsh') -NoLogo -NoProfile -NonInteractive -File $publishScript -ProjectPath $created.Path -ModuleRoot $moduleRoot
            $LASTEXITCODE | Should -Be 0
            $before = Get-Content $env:GERBER_CONFIG_PATH -Raw
            $probe = Join-Path $repositoryRoot 'tests/TestHelpers/Invoke-GerberPluginRestartProbe.ps1'
            $output = '' | & (Join-Path $PSHOME 'pwsh') -NoLogo -NoProfile -File $probe -CoreManifest $coreManifest -ModuleRoot $moduleRoot
            $LASTEXITCODE | Should -Be 0
            ($output -join "`n") | Should -Match 'mycompany'
            ($output -join "`n") | Should -Match 'Hello from Gerber.MyCompany!'
            ($output -join "`n") | Should -Match 'Gerber.MyCompany\s+0.1.0\s+'
            (Get-Content $env:GERBER_CONFIG_PATH -Raw) | Should -Be $before
            $publishedManifestPath = Join-Path $moduleRoot "$($created.Name)/$($created.Version)/$($created.Name).psd1"
            $publishedManifestPath | Should -Exist
            $manifest = Import-PowerShellDataFile -LiteralPath $publishedManifestPath -ErrorAction Stop
            $manifest.GUID.ToString() | Should -Be $created.Guid
            $manifest.PrivateData.Gerber.Keys | Should -Not -Contain 'Guid'
        } finally {
            $env:GERBER_CONFIG_PATH = $originalConfig
            Remove-Module Gerber.MyCompany -Force -ErrorAction SilentlyContinue
        }
    }
}
