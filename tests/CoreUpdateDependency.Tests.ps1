# Cross-cutting dependency contract: project metadata declares one numeric PMU minimum.
BeforeAll {
    $root = Split-Path -Parent $PSScriptRoot
    $script:project = Get-Content -LiteralPath "$root/project.json" -Raw | ConvertFrom-Json
}

Describe 'Core update dependency minimum' -Tag 'GerberPmuDependency' {
    It 'declares one numeric PMU minimum without pinning a specific release in the test' {
        $requirement = @($script:project.Manifest.RequiredModules | Where-Object ModuleName -EQ 'PSModuleUpdate')
        $requirement.Count | Should -Be 1
        $requirement[0].ModuleVersion | Should -Match '^[0-9]+\.[0-9]+\.[0-9]+$'
        [version]$requirement[0].ModuleVersion | Should -BeGreaterThan ([version]'0.0.0')
    }
}
